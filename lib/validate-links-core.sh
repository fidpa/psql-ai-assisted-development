#!/bin/bash
# Copyright (c) 2025 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/bash-markdown-link-validator
#
# validate-links-core.sh - Link Validation Library
# Version: 1.2.3
#
# VENDORED COPY — do not edit casually.
#   Upstream: https://github.com/fidpa/bash-markdown-link-validator
#   Vendored: 2026-08-09, from upstream v1.2.3, MIT, same copyright holder.
#   Vendored rather than installed so that `bash scripts/validate-all-areas.sh`
#   works on a fresh clone with no external dependency.
#
#   LOCAL PATCHES against upstream v1.2.3 (marked `PATCH(psql-ai):` in the code,
#   grep for that string to find all of them). They belong upstream and should
#   be contributed back; until then this copy differs:
#
#   1. Link extraction accepted only targets containing ".md". In this repository
#      that silently skipped 38 anchor-only links (`](#vision--mission)`) and
#      every link to a non-markdown file (`../../scripts/backup-postgres.sh`,
#      `../../config/postgres-tuning-64gb.conf`) — roughly 44 of ~374 links were
#      never checked while the report said "0 broken". Now every local target is
#      extracted; external URLs are still skipped early as before.
#
#   2. build_anchor_index() recognised only HTML `id="..."` attributes, not the
#      markdown form `{#slug}`. A heading `## VISION & MISSION {#vision--mission}`
#      therefore produced the slug `vision-mission-vision-mission` and the link
#      `](#vision--mission)` did not resolve. The explicit id is now extracted,
#      and the `{#...}` suffix is stripped before the heading text is slugged.
#
# shellcheck disable=SC2034  # Exported variables used by callers
#
# Features:
# - Smart anchor resolution (suffix-match, umlaut normalization, numbered sections)
# - Parallel processing with configurable job count
# - JSON output for CI/CD integration
# - Batch-fix mode for link pattern replacement
# - Deep path warnings and auto-TODO marking
# - Code-block awareness (skips links inside fenced and inline code)

set -uo pipefail  # NO set -e!

# ============================================================================
# GLOBAL VARIABLES (Exported for background jobs)
# ============================================================================

# Color codes (set by setup_colors, exported for parallel jobs)
GREEN="" RED="" YELLOW="" BLUE="" CYAN="" MAGENTA="" NC=""

# Counters (global, modified by scan functions)
declare -gi total_files=0
declare -gi total_links=0
declare -gi valid_links=0
declare -gi broken_links=0
declare -gi warnings=0
declare -gi total_links_external=0
declare -gi valid_links_external=0
declare -gi total_links_internal=0
declare -gi valid_links_internal=0
declare -gi deep_path_warnings=0
declare -gi auto_todo_fixes=0
declare -gi skipped_external_urls=0

# Anchor cache (associative array)
declare -gA ANCHOR_CACHE

# Global anchor cache (- cache warming)
declare -gA GLOBAL_ANCHOR_CACHE

# Options (set by caller before sourcing)
VERBOSE=${VERBOSE:-false}
COLOR_OUTPUT=${COLOR_OUTPUT:-true}
PARALLEL_JOBS=${PARALLEL_JOBS:-2}
OUTPUT_FORMAT=${OUTPUT_FORMAT:-text}  # text or json
FIX_PATTERN=${FIX_PATTERN:-""}        # OLD_PATH:NEW_PATH for batch fix
AUTO_TODO=${AUTO_TODO:-false}         # Auto-mark missing files as TODO
WARN_DEEP_PATHS=${WARN_DEEP_PATHS:-true}  # Warn on deep relative paths
MAX_PATH_DEPTH=${MAX_PATH_DEPTH:-5}   # Max ../ levels before warning

# JSON output buffer
declare -ga JSON_RESULTS=()
declare -ga JSON_BROKEN_LINKS=()
declare -ga JSON_WARNINGS=()
declare -ga JSON_DEEP_PATHS=()

# Paths (MUST be set by caller before sourcing library)
# AREA_DIR, PROJECT_ROOT, DOCS_DIR, EXCLUDE_DIRS, AREA_NAME

# ============================================================================
# COLOR SETUP
# ============================================================================

setup_colors() {
    if [[ $COLOR_OUTPUT == true ]] && [[ -t 1 ]]; then
        GREEN='\033[0;32m'
        RED='\033[0;31m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        MAGENTA='\033[0;35m'
        NC='\033[0m'
    else
        GREEN="" RED="" YELLOW="" BLUE="" CYAN="" MAGENTA="" NC=""
    fi

    # Export for background jobs
    export GREEN RED YELLOW BLUE CYAN MAGENTA NC
}

# ============================================================================
# PLATFORM COMPATIBILITY
# ============================================================================

# Platform-agnostic sed in-place editing
sed_inplace() {
    if sed --version 2>&1 | grep -q GNU; then
        # GNU sed (Linux)
        sed -i "$@"
    else
        # BSD sed (macOS)
        sed -i '' "$@"
    fi
}

# ============================================================================
# ANCHOR HANDLING (Caching)
# ============================================================================

normalize_anchor() {
    local anchor="$1"
    # Remove leading #
    anchor="${anchor#\#}"
    # Transliterate UPPERCASE umlauts to ASCII FIRST (locale-independent).
    # ${,,} below only lowercases Ä/Ö/Ü in UTF-8 locales; under a non-UTF-8
    # locale (e.g. LC_ALL=C) they survive, miss the lowercase transliterations,
    # and get deleted by the [^a-z0-9] filter → "Übersicht" becomes "bersicht".
    anchor="${anchor//Ä/a}"
    anchor="${anchor//Ö/o}"
    anchor="${anchor//Ü/u}"
    anchor="${anchor//ẞ/ss}"
    # Convert to lowercase (bash 4.0+)
    anchor="${anchor,,}"
    # Replace umlauts FIRST (before non-ASCII → -)
    # Prevents logic bug: ü→- instead of ü→u
    anchor="${anchor//ß/ss}"
    anchor="${anchor//ü/u}"
    anchor="${anchor//ö/o}"
    anchor="${anchor//ä/a}"
    # Replace non-alphanumeric with -, remove duplicate/trailing -
    echo "$anchor" | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-\|-$//g'
}

build_anchor_index() {
    local file="$1"

    # Skip if already cached
    [[ -n "${ANCHOR_CACHE[$file]:-}" ]] && return 0

    local anchors=""

    # Extract anchors from markdown headers
    while IFS= read -r line; do
        # Match lines starting with # (headers)
        if [[ "$line" =~ ^#+[[:space:]](.+)$ ]]; then
            local header="${BASH_REMATCH[1]}"
            local anchor

            # PATCH(psql-ai): explicit markdown anchor `## Heading {#slug}`.
            # The slug is authoritative — GitHub uses it verbatim — and the
            # `{#...}` part must not end up in the slug derived from the text,
            # or `## VISION & MISSION {#vision--mission}` yields the nonsense
            # anchor `vision-mission-vision-mission`.
            if [[ "$header" =~ \{#([^}]+)\}[[:space:]]*$ ]]; then
                anchors+="$(normalize_anchor "${BASH_REMATCH[1]}")"$'\n'
                header="${header%%\{#*}"
            fi

            anchor=$(normalize_anchor "$header")
            anchors+="$anchor"$'\n'
        fi
    done < "$file"

    # Also extract explicit id="..." attributes (POSIX-compatible)
    local explicit_ids
    explicit_ids=$(grep -o 'id="[^"]*"' "$file" 2>/dev/null | sed 's/id="//;s/"$//' || true)
    # Normalize IDs (same as headers)
    while IFS= read -r id; do
        [[ -n "$id" ]] && anchors+="$(normalize_anchor "$id")"$'\n'
    done <<< "$explicit_ids"

    # Store in cache
    ANCHOR_CACHE[$file]="$anchors"
}

validate_anchor_exists() {
    local file="$1"
    local anchor="$2"

    # Build index if not cached
    build_anchor_index "$file"

    # Normalize search anchor
    local anchor_clean
    anchor_clean=$(normalize_anchor "$anchor")

    # Check in cached anchors (exact match)
    if echo "${ANCHOR_CACHE[$file]}" | grep -qFx "$anchor_clean"; then
        return 0
    fi

    # Fuzzy matching for numbered sections
    # Pattern: #25-troubleshooting might be #2-5-troubleshooting
    # Check if anchor starts with digits and add hyphen variants
    if [[ $anchor_clean =~ ^([0-9])([0-9]+)- ]]; then
        local first_digit="${BASH_REMATCH[1]}"
        local remaining_digits="${BASH_REMATCH[2]}"
        local suffix="${anchor_clean#"$first_digit""$remaining_digits"-}"

        # Try variant with hyphen between digits: #25- → #2-5-
        local fuzzy_anchor="${first_digit}-${remaining_digits}-${suffix}"
        if echo "${ANCHOR_CACHE[$file]}" | grep -qFx "$fuzzy_anchor"; then
            return 0
        fi
    fi

    # Suffix-Matching for anchors without section numbers
    # Example: "prepared-statements-parameterized-queries" matches
    #          "2-3-prepared-statements-parameterized-queries"
    if ! [[ $anchor_clean =~ ^[0-9]+-[0-9]+- ]]; then
        # Anchor has no section number prefix → try suffix match
        local suffix_pattern="-${anchor_clean}$"
        if echo "${ANCHOR_CACHE[$file]}" | grep -qE "^[0-9]+-[0-9]+${suffix_pattern}"; then
            return 0
        fi
    fi

    # Umlaut handling moved to normalize_anchor()
    # This block is now obsolete - umlauts are ALWAYS converted to ASCII
    # before reaching here. Removed for code simplification.

    return 1
}

# ============================================================================
# OPTIMIZATIONS - Path Depth, Normalization, Cache Warming
# ============================================================================

# Count depth of relative path (number of ../)
count_path_depth() {
    local path="$1"
    echo "$path" | grep -o '\.\.\/' | wc -l
}

# Warn about deep relative paths
warn_deep_path() {
    local source_file="$1"
    local link="$2"
    local line_num="$3"
    local depth="$4"

    if [[ $WARN_DEEP_PATHS == true ]] && [[ $depth -gt $MAX_PATH_DEPTH ]]; then
        deep_path_warnings=$((deep_path_warnings + 1))
        echo -e "  ${MAGENTA}📏${NC} Line $line_num: Deep path ($depth levels): $link"
        [[ $VERBOSE == true ]] && echo -e "      Consider: absolute path from DOCS_DIR or shorter relative"

        # Add to JSON buffer if JSON output
        if [[ $OUTPUT_FORMAT == "json" ]]; then
            JSON_DEEP_PATHS+=("{\"file\":\"$source_file\",\"line\":$line_num,\"link\":\"$link\",\"depth\":$depth}")
        fi
    fi
}

# Normalize relative path (remove redundant ../ patterns)
normalize_relative_path() {
    local path="$1"

    # Simply return path without modification - let realpath handle it
    # This avoids breaking relative path resolution
    echo "$path"
}

# Cache warming - pre-build anchor index for all files
warm_anchor_cache() {
    local area_dir="$1"

    [[ $VERBOSE == true ]] && echo -e "${BLUE}Warming anchor cache...${NC}"

    local count=0
    while IFS= read -r file; do
        build_anchor_index "$file"
        count=$((count + 1))
    done < <(find "$area_dir" -name "*.md" -type f 2>/dev/null)

    [[ $VERBOSE == true ]] && echo -e "${GREEN}Cached anchors for $count files${NC}"
}

# ============================================================================
# SED ESCAPE UTILITIES (Security Fix)
# ============================================================================

# Escape string for use as sed regex pattern
# Prevents: Links with |, &, \, [, ], (, ) → sed matches wrong or corrupts files
escape_sed_pattern() {
    local input="${1:-}"
    # Escape: . [ \ * ^ $ ( ) + ? { } | and delimiters / |
    printf '%s' "$input" | sed -e 's/[.[\*^$()+?{}|\\]/\\&/g' -e 's|/|\\/|g'
}

# Escape string for use as sed replacement
# Only & and \ have special meaning in replacement
escape_sed_replacement() {
    local input="${1:-}"
    printf '%s' "$input" | sed -e 's/[&\\]/\\&/g' -e 's|/|\\/|g'
}

# ============================================================================
# BATCH-FIX MODE
# ============================================================================

# Apply batch fix pattern to a file
apply_batch_fix() {
    local source_file="$1"
    local link="$2"
    local line_num="$3"

    [[ -z "$FIX_PATTERN" ]] && return 1

    local old_pattern="${FIX_PATTERN%%:*}"
    local new_pattern="${FIX_PATTERN#*:}"

    if [[ "$link" == *"$old_pattern"* ]]; then
        local new_link="${link//$old_pattern/$new_pattern}"
        echo -e "  ${GREEN}🔧${NC} Line $line_num: Fixing: $link → $new_link"

        # Use escaped patterns to prevent sed injection/corruption
        local escaped_link escaped_new_link
        escaped_link=$(escape_sed_pattern "$link")
        escaped_new_link=$(escape_sed_replacement "$new_link")
        sed_inplace "s|${escaped_link}|${escaped_new_link}|g" -- "$source_file"
        return 0
    fi

    return 1
}

# ============================================================================
# AUTO-TODO MARKING
# ============================================================================

# Mark broken link as TODO in source file
mark_as_todo() {
    local source_file="$1"
    local link="$2"
    local line_num="$3"

    [[ $AUTO_TODO != true ]] && return 1

    # Only mark if file has no git history (truly missing, not moved)
    local target_name
    target_name=$(basename "$link" .md)
    if git log --all --oneline -- "**/$target_name.md" 2>/dev/null | head -1 | grep -q .; then
        # File was moved, don't mark as TODO
        [[ $VERBOSE == true ]] && echo -e "      Git history found - not marking as TODO"
        return 1
    fi

    # Use escape function instead of manual escaping (security fix)
    local escaped_link
    escaped_link=$(escape_sed_pattern "$link")
    local escaped_target
    escaped_target=$(escape_sed_replacement "\`$target_name.md\` (TODO: to create)")
    sed_inplace "s|\[[^]]*\](${escaped_link})|${escaped_target}|g" -- "$source_file"

    auto_todo_fixes=$((auto_todo_fixes + 1))
    echo -e "  ${CYAN}📝${NC} Line $line_num: Marked as TODO: $link"

    return 0
}

# ============================================================================
# PATH RESOLUTION (External Link Support, Normalization)
# ============================================================================

resolve_relative_path() {
    local base_file="$1"
    local link="$2"
    local base_dir

    base_dir=$(dirname "$base_file")

    local resolved_path=""

    # Handle absolute paths from docs root
    if [[ "$link" == /* ]]; then
        resolved_path="$DOCS_DIR$link"
    # Handle parent directory traversal (cross-DIATAXIS links)
    elif [[ "$link" == ../* ]]; then
        resolved_path="$base_dir/$link"
    # Handle same-directory relative links
    else
        resolved_path="$base_dir/$link"
    fi

    # Normalize the path
    normalize_relative_path "$resolved_path"
}

# ============================================================================
# LINK VALIDATION (Internal/External)
# ============================================================================

validate_link() {
    local source_file="$1"
    local link="$2"
    local line_num="$3"

    # Note: External URLs (http/https/ftp/mailto) are now filtered early in scan_file()
    # This function only handles file-based links

    # Check path depth and warn if too deep
    local path_depth
    path_depth=$(count_path_depth "$link")
    if [[ $path_depth -gt $MAX_PATH_DEPTH ]]; then
        warn_deep_path "$source_file" "$link" "$line_num" "$path_depth"
    fi

    # Handle anchor-only links (same file)
    if [[ "$link" =~ ^#.* ]]; then
        if validate_anchor_exists "$source_file" "$link"; then
            [[ $OUTPUT_FORMAT != "json" ]] && [[ $VERBOSE == true ]] && echo -e "  ${GREEN}✅${NC} Line $line_num: Anchor valid: $link"
            return 0
        else
            [[ $OUTPUT_FORMAT != "json" ]] && echo -e "  ${RED}❌${NC} Line $line_num: Anchor not found: $link"
            # Add to JSON buffer
            [[ $OUTPUT_FORMAT == "json" ]] && JSON_BROKEN_LINKS+=("{\"file\":\"$source_file\",\"line\":$line_num,\"link\":\"$link\",\"type\":\"anchor\"}")
            return 1
        fi
    fi

    # Split file path and anchor
    local file_path="${link%#*}"
    local anchor=""
    if [[ "$link" == *"#"* ]]; then
        anchor="#${link#*#}"
    fi

    # Try batch-fix first if pattern is set
    if [[ -n "$FIX_PATTERN" ]]; then
        if apply_batch_fix "$source_file" "$link" "$line_num"; then
            return 0  # Fixed, consider valid
        fi
    fi

    # Resolve the target path (includes normalization)
    local target_path
    target_path=$(resolve_relative_path "$source_file" "$file_path")

    # Additional normalization with realpath if available
    if command -v realpath >/dev/null 2>&1; then
        target_path=$(realpath -m "$target_path" 2>/dev/null || echo "$target_path")
    fi

    # Determine if link is internal or external to AREA_DIR
    local is_external=false
    # shellcheck disable=SC2153  # AREA_DIR is set by caller script before sourcing
    if [[ ! "$target_path" =~ ^"$AREA_DIR" ]]; then
        is_external=true
    fi

    # Check if file exists
    if [[ ! -f "$target_path" ]]; then
        # Try auto-TODO marking
        if [[ $AUTO_TODO == true ]]; then
            if mark_as_todo "$source_file" "$link" "$line_num"; then
                return 0  # Marked as TODO, don't count as broken
            fi
        fi

        if [[ $OUTPUT_FORMAT != "json" ]]; then
            if [[ "$is_external" == true ]]; then
                echo -e "  ${RED}❌${NC} Line $line_num: External link broken: $file_path"
                [[ $VERBOSE == true ]] && echo -e "      Resolved to: $target_path"
            else
                echo -e "  ${RED}❌${NC} Line $line_num: File not found: $file_path"
                [[ $VERBOSE == true ]] && echo -e "      Resolved to: $target_path"
            fi
        fi

        # Add to JSON buffer
        [[ $OUTPUT_FORMAT == "json" ]] && JSON_BROKEN_LINKS+=("{\"file\":\"$source_file\",\"line\":$line_num,\"link\":\"$link\",\"type\":\"file_not_found\"}")
        return 1
    fi

    # Check anchor if present
    if [[ -n "$anchor" ]]; then
        if ! validate_anchor_exists "$target_path" "$anchor"; then
            [[ $OUTPUT_FORMAT != "json" ]] && echo -e "  ${YELLOW}⚠️${NC}  Line $line_num: Anchor not found: $anchor in $file_path"
            [[ $OUTPUT_FORMAT == "json" ]] && JSON_WARNINGS+=("{\"file\":\"$source_file\",\"line\":$line_num,\"link\":\"$link\",\"type\":\"anchor_not_found\"}")
            return 2  # Warning, not error
        fi
    fi

    # Warn about links to archive (deprecated content)
    if [[ "$target_path" == *"/archive/"* ]]; then
        [[ $OUTPUT_FORMAT != "json" ]] && [[ $VERBOSE == true ]] && \
            echo -e "  ${YELLOW}⚠️${NC}  Line $line_num: Link to archive (deprecated): $file_path"
    fi

    # Enhanced verbose output for external links
    if [[ $OUTPUT_FORMAT != "json" ]] && [[ $VERBOSE == true ]]; then
        if [[ "$is_external" == true ]]; then
            echo -e "  ${GREEN}✅${NC} Line $line_num: External link valid: $link"
        else
            echo -e "  ${GREEN}✅${NC} Line $line_num: $link"
        fi
    fi

    # Return external link indicator (3 = valid external link)
    if [[ "$is_external" == true ]]; then
        return 3
    fi

    return 0
}

# ============================================================================
# FILE SCANNING (Sequential)
# ============================================================================

# ============================================================================
# CODE-BLOCK AWARENESS (skip links inside fenced/inline code)
# ============================================================================

# Return the line numbers that fall inside fenced code blocks (``` or ~~~),
# space-separated. Honors variable fence length per CommonMark: a block opened
# with N fence chars is only closed by a line with >= N identical chars and no
# info string -- so a 4-backtick example block may contain literal 3-backtick
# blocks without closing prematurely.
compute_code_block_lines() {
    local file="$1"
    local fence_re='^[[:space:]]{0,3}(`{3,}|~{3,})'
    local in_fence=""        # empty = outside; otherwise "char:len"
    local lineno=0
    local result=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        if [[ "$line" =~ $fence_re ]]; then
            local marker="${BASH_REMATCH[1]}"
            local fchar="${marker:0:1}"
            local flen="${#marker}"
            if [[ -z "$in_fence" ]]; then
                in_fence="${fchar}:${flen}"
                result+=" $lineno"
            else
                local cur_char="${in_fence%%:*}"
                local cur_len="${in_fence##*:}"
                local rest="${line#*"$marker"}"
                if [[ "$fchar" == "$cur_char" ]] && [[ $flen -ge $cur_len ]] && [[ "$rest" =~ ^[[:space:]]*$ ]]; then
                    in_fence=""   # closing fence
                fi
                result+=" $lineno"
            fi
        elif [[ -n "$in_fence" ]]; then
            result+=" $lineno"
        fi
    done < "$file"

    echo "$result"
}

# Strip inline-code spans (`...`) from a line so links inside them are not
# treated as real links (e.g. format examples in documentation-about-docs).
strip_inline_code() {
    printf '%s' "$1" | sed 's/`[^`]*`//g'
}

scan_file() {
    local file="$1"
    local relative_file

    # Get relative path from area directory
    relative_file=$(realpath --relative-to="$AREA_DIR" "$file" 2>/dev/null || basename "$file")

    [[ $OUTPUT_FORMAT != "json" ]] && echo -e "${BLUE}Scanning:${NC} $relative_file"

    local file_broken=0
    local file_links=0
    local file_valid=0

    # Process each line with links (non-greedy link text match)
    local grep_output
    grep_output=$(grep -n '\[[^]]*\]([^)]*)' "$file" 2>/dev/null || true)  # PATCH(psql-ai): was '...*.md[^)]*', which skipped anchor-only and non-markdown targets

    # Lines inside fenced code blocks (skipped - example content, not real links)
    local cb_lines
    cb_lines=$(compute_code_block_lines "$file")

    if [[ -n "$grep_output" ]]; then
        while IFS=: read -r line_num line_content; do
            [[ -z "$line_content" ]] && continue
            # Skip links inside fenced code blocks
            [[ " $cb_lines " == *" $line_num "* ]] && continue

            # Extract links from this line (strip inline-code spans first)
            local links
            links=$(strip_inline_code "$line_content" | grep -o '\[[^]]*\]([^)]*)' | \
                sed 's/.*](\([^)]*\)).*/\1/' || true)

            # Validate each link
            while IFS= read -r link; do
                [[ -z "$link" ]] && continue

                # Skip external URLs (http/https/ftp/mailto) early - don't count in total_links
                if [[ "$link" =~ ^https?:// ]] || [[ "$link" =~ ^ftp:// ]] || [[ "$link" =~ ^mailto: ]]; then
                    skipped_external_urls=$((skipped_external_urls + 1))
                    [[ $OUTPUT_FORMAT != "json" ]] && [[ $VERBOSE == true ]] && echo -e "  ${CYAN}⏭${NC}  Line $line_num: External link skipped: $link"
                    continue
                fi

                file_links=$((file_links + 1))
                total_links=$((total_links + 1))

                # Track internal vs external links
                validate_link "$file" "$link" "$line_num"
                local result=$?

                if [[ $result -eq 0 ]] || [[ $result -eq 3 ]]; then
                    file_valid=$((file_valid + 1))
                    valid_links=$((valid_links + 1))

                    # Track internal vs external
                    if [[ $result -eq 3 ]]; then
                        total_links_external=$((total_links_external + 1))
                        valid_links_external=$((valid_links_external + 1))
                    else
                        total_links_internal=$((total_links_internal + 1))
                        valid_links_internal=$((valid_links_internal + 1))
                    fi
                elif [[ $result -eq 2 ]]; then
                    # Warning (anchor not found, but file exists)
                    file_valid=$((file_valid + 1))
                    valid_links=$((valid_links + 1))
                    warnings=$((warnings + 1))
                else
                    file_broken=$((file_broken + 1))
                    broken_links=$((broken_links + 1))
                fi
            done <<< "$links"
        done <<< "$grep_output"
    fi

    if [[ $file_links -gt 0 ]] && [[ $OUTPUT_FORMAT != "json" ]]; then
        local success_rate=$((file_valid * 100 / file_links))
        if [[ $file_broken -eq 0 ]]; then
            echo -e "  ${GREEN}✓${NC} $file_links links, all valid (${success_rate}%)"
        else
            echo -e "  ${RED}✗${NC} $file_links links, $file_broken broken (${success_rate}% valid)"
        fi
    fi

    total_files=$((total_files + 1))
}

# ============================================================================
# FILE SCANNING (Parallel Batch Processing)
# ============================================================================

scan_file_parallel() {
    local file="$1"
    local output_file="$2"

    exec </dev/null  # Prevent stdin hanging

    local relative_file
    relative_file=$(realpath --relative-to="$AREA_DIR" "$file" 2>/dev/null || basename "$file")

    local output=""
    output+="SCANNING: $relative_file"$'\n'

    local file_broken=0
    local file_links=0
    local file_valid=0
    local file_internal=0
    local file_external=0
    # Track warnings, deep_path, auto_todo locally (parallel mode fix)
    local file_warnings=0
    local file_deep_path=0
    local file_auto_todo=0
    local file_skipped_external=0

    # Process each line with links (non-greedy link text match)
    local grep_output
    grep_output=$(grep -n '\[[^]]*\]([^)]*)' "$file" 2>/dev/null || true)  # PATCH(psql-ai): was '...*.md[^)]*', which skipped anchor-only and non-markdown targets

    # Lines inside fenced code blocks (skipped - example content, not real links)
    local cb_lines
    cb_lines=$(compute_code_block_lines "$file")

    if [[ -n "$grep_output" ]]; then
        while IFS=: read -r line_num line_content; do
            [[ -z "$line_content" ]] && continue
            # Skip links inside fenced code blocks
            [[ " $cb_lines " == *" $line_num "* ]] && continue

            # Extract links from this line (strip inline-code spans first)
            local links
            links=$(strip_inline_code "$line_content" | grep -o '\[[^]]*\]([^)]*)' | \
                sed 's/.*](\([^)]*\)).*/\1/' || true)

            # Validate each link
            while IFS= read -r link; do
                [[ -z "$link" ]] && continue

                # Skip external URLs (http/https/ftp/mailto) early - don't count in file_links
                if [[ "$link" =~ ^https?:// ]] || [[ "$link" =~ ^ftp:// ]] || [[ "$link" =~ ^mailto: ]]; then
                    file_skipped_external=$((file_skipped_external + 1))
                    continue
                fi

                file_links=$((file_links + 1))

                # Capture validation output
                local validation_output
                validation_output=$(validate_link "$file" "$link" "$line_num" 2>&1)
                local result=$?

                # Track local counters by parsing output markers
                [[ "$validation_output" == *"📏"* ]] && file_deep_path=$((file_deep_path + 1))
                [[ "$validation_output" == *"📝"* ]] && file_auto_todo=$((file_auto_todo + 1))

                # Append validation output
                [[ -n "$validation_output" ]] && output+="$validation_output"$'\n'

                if [[ $result -eq 0 ]] || [[ $result -eq 3 ]]; then
                    file_valid=$((file_valid + 1))
                    if [[ $result -eq 3 ]]; then
                        file_external=$((file_external + 1))
                    else
                        file_internal=$((file_internal + 1))
                    fi
                elif [[ $result -eq 2 ]]; then
                    file_valid=$((file_valid + 1))
                    file_warnings=$((file_warnings + 1))  # Track warnings
                else
                    file_broken=$((file_broken + 1))
                fi
            done <<< "$links"
        done <<< "$grep_output"
    fi

    if [[ $file_links -gt 0 ]]; then
        local success_rate=$((file_valid * 100 / file_links))
        if [[ $file_broken -eq 0 ]]; then
            output+="SUMMARY: $file_links links, all valid (${success_rate}%)"$'\n'
        else
            output+="SUMMARY: $file_links links, $file_broken broken (${success_rate}% valid)"$'\n'
        fi
    fi

    # Write stats to output file (single write operation)
    # Include warnings, deep_path, auto_todo, skipped_external in stats
    {
        printf "STATS: files=1 links=%d valid=%d broken=%d internal=%d external=%d warnings=%d deep=%d todo=%d skipped=%d\n" \
            "$file_links" "$file_valid" "$file_broken" "$file_internal" "$file_external" \
            "$file_warnings" "$file_deep_path" "$file_auto_todo" "$file_skipped_external"
        printf "%s" "$output"
    } > "$output_file"
}

# Export function for parallel jobs
export -f scan_file_parallel validate_link resolve_relative_path normalize_anchor \
    build_anchor_index validate_anchor_exists count_path_depth warn_deep_path \
    normalize_relative_path apply_batch_fix mark_as_todo \
    escape_sed_pattern escape_sed_replacement \
    compute_code_block_lines strip_inline_code

# ============================================================================
# STATS AGGREGATION (Parallel Mode)
# ============================================================================

aggregate_parallel_stats() {
    local temp_dir="$1"

    # Aggregate stats from all output files
    for output_file in "$temp_dir"/output_*.txt; do
        [[ ! -f "$output_file" ]] && continue

        # Extract stats line
        local stats_line
        stats_line=$(grep "^STATS:" "$output_file" 2>/dev/null || true)
        [[ -z "$stats_line" ]] && continue

        # Parse stats (POSIX-compatible)
        # Include warnings, deep, todo, skipped fields
        local file_files file_links file_valid file_broken file_internal file_external
        local file_warnings file_deep file_todo file_skipped
        file_files=$(echo "$stats_line" | sed -n 's/.*files=\([0-9]*\).*/\1/p'); [[ -z "$file_files" ]] && file_files=0
        file_links=$(echo "$stats_line" | sed -n 's/.*links=\([0-9]*\).*/\1/p'); [[ -z "$file_links" ]] && file_links=0
        file_valid=$(echo "$stats_line" | sed -n 's/.*valid=\([0-9]*\).*/\1/p'); [[ -z "$file_valid" ]] && file_valid=0
        file_broken=$(echo "$stats_line" | sed -n 's/.*broken=\([0-9]*\).*/\1/p'); [[ -z "$file_broken" ]] && file_broken=0
        file_internal=$(echo "$stats_line" | sed -n 's/.*internal=\([0-9]*\).*/\1/p'); [[ -z "$file_internal" ]] && file_internal=0
        file_external=$(echo "$stats_line" | sed -n 's/.*external=\([0-9]*\).*/\1/p'); [[ -z "$file_external" ]] && file_external=0
        file_warnings=$(echo "$stats_line" | sed -n 's/.*warnings=\([0-9]*\).*/\1/p'); [[ -z "$file_warnings" ]] && file_warnings=0
        file_deep=$(echo "$stats_line" | sed -n 's/.*deep=\([0-9]*\).*/\1/p'); [[ -z "$file_deep" ]] && file_deep=0
        file_todo=$(echo "$stats_line" | sed -n 's/.*todo=\([0-9]*\).*/\1/p'); [[ -z "$file_todo" ]] && file_todo=0
        file_skipped=$(echo "$stats_line" | sed -n 's/.*skipped=\([0-9]*\).*/\1/p'); [[ -z "$file_skipped" ]] && file_skipped=0

        # Update global counters
        total_files=$((total_files + file_files))
        total_links=$((total_links + file_links))
        valid_links=$((valid_links + file_valid))
        broken_links=$((broken_links + file_broken))
        total_links_internal=$((total_links_internal + file_internal))
        total_links_external=$((total_links_external + file_external))
        valid_links_internal=$((valid_links_internal + file_internal))
        valid_links_external=$((valid_links_external + file_external))
        # Aggregate warnings, deep_path, auto_todo, skipped_external
        warnings=$((warnings + file_warnings))
        deep_path_warnings=$((deep_path_warnings + file_deep))
        auto_todo_fixes=$((auto_todo_fixes + file_todo))
        skipped_external_urls=$((skipped_external_urls + file_skipped))

        # Print output (excluding STATS line)
        grep -v "^STATS:" "$output_file" || true
    done
}

# ============================================================================
# VALIDATION ORCHESTRATION
# ============================================================================

validate_sequential() {
    local -a files=("$@")

    for file in "${files[@]}"; do
        scan_file "$file"
    done
}

validate_parallel() {
    local -a files=("$@")

    # Create temp directory for parallel output
    local temp_dir
    temp_dir=$(mktemp -d) || {
        echo "ERROR: Cannot create temp directory" >&2
        return 2
    }

    # Launch parallel jobs
    local counter=0
    local -a pids=()

    for file in "${files[@]}"; do
        # Throttle to PARALLEL_JOBS concurrent jobs
        while [[ ${#pids[@]} -ge $PARALLEL_JOBS ]]; do
            # Wait for any job to finish
            wait -n 2>/dev/null || true
            # Remove finished PIDs
            local -a new_pids=()
            for pid in "${pids[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                    new_pids+=("$pid")
                fi
            done
            pids=("${new_pids[@]}")
        done

        # Launch background job
        scan_file_parallel "$file" "$temp_dir/output_$(printf "%05d" $counter).txt" &
        pids+=($!)
        counter=$((counter + 1))
    done

    # Wait for all remaining jobs
    wait 2>/dev/null || true

    # Aggregate stats and display output
    aggregate_parallel_stats "$temp_dir"

    # Cleanup
    rm -rf "$temp_dir"
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-color)
                COLOR_OUTPUT=false
                shift
                ;;
            -j|--parallel-jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            --parallel-jobs=*)
                PARALLEL_JOBS="${1#*=}"
                shift
                ;;
            # New options
            --output-format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --output-format=*)
                OUTPUT_FORMAT="${1#*=}"
                shift
                ;;
            --fix-pattern)
                FIX_PATTERN="$2"
                shift 2
                ;;
            --fix-pattern=*)
                FIX_PATTERN="${1#*=}"
                shift
                ;;
            --auto-todo)
                AUTO_TODO=true
                shift
                ;;
            --no-deep-path-warning)
                WARN_DEEP_PATHS=false
                shift
                ;;
            --max-path-depth)
                MAX_PATH_DEPTH="$2"
                shift 2
                ;;
            --max-path-depth=*)
                MAX_PATH_DEPTH="${1#*=}"
                shift
                ;;
            --warm-cache)
                # Cache warming is enabled by calling warm_anchor_cache before validation
                WARM_CACHE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_usage
                exit 2
                ;;
        esac
    done
}

# ============================================================================
# SUMMARY REPORTING
# ============================================================================

print_validation_header() {
    [[ $OUTPUT_FORMAT == "json" ]] && return  # Skip header in JSON mode
    echo "========================================"
    echo "Link Validation Report - $AREA_NAME"
    echo "========================================"
    echo ""
}

print_summary_report() {
    # JSON output mode
    if [[ $OUTPUT_FORMAT == "json" ]]; then
        print_json_report
        return
    fi

    echo ""
    echo "========================================"
    echo "Summary"
    echo "========================================"
    echo "Total files scanned: $total_files"
    echo "Total links found: $total_links"

    # Show internal/external breakdown if applicable
    if [[ $total_links_internal -gt 0 ]] || [[ $total_links_external -gt 0 ]]; then
        echo "  Internal links: $total_links_internal"
        echo "  External links: $total_links_external"
    fi

    echo "Valid links: $valid_links"

    # Show internal/external valid breakdown
    if [[ $valid_links_internal -gt 0 ]] || [[ $valid_links_external -gt 0 ]]; then
        echo "  Internal valid: $valid_links_internal"
        echo "  External valid: $valid_links_external"
    fi

    echo "Broken links: $broken_links"
    [[ $warnings -gt 0 ]] && echo "Warnings: $warnings"

    # Show deep path warnings
    [[ $deep_path_warnings -gt 0 ]] && echo "Deep path warnings: $deep_path_warnings"

    # Show auto-TODO fixes
    [[ $auto_todo_fixes -gt 0 ]] && echo "Auto-TODO fixes: $auto_todo_fixes"

    # Show skipped external URLs
    [[ $skipped_external_urls -gt 0 ]] && echo "Skipped external URLs: $skipped_external_urls"

    if [[ $total_links -gt 0 ]]; then
        local success_rate=$((valid_links * 100 / total_links))
        echo "Success rate: ${success_rate}%"
    fi

    echo "========================================"
}

# JSON output format for CI/CD integration
# TODO: Implement JSON escaping for CI/CD integration
#   - Issue: Paths with ", \, newlines create invalid JSON
#   - Solution: Add json_escape() function for all string fields
#   - Affected: AREA_NAME, JSON_BROKEN_LINKS[], JSON_WARNINGS[], JSON_DEEP_PATHS[]
print_json_report() {
    local success_rate=0
    if [[ $total_links -gt 0 ]]; then
        success_rate=$((valid_links * 100 / total_links))
    fi

    cat <<EOF
{
  "summary": {
    "area": "$AREA_NAME",
    "total_files": $total_files,
    "total_links": $total_links,
    "internal_links": $total_links_internal,
    "external_links": $total_links_external,
    "valid_links": $valid_links,
    "broken_links": $broken_links,
    "warnings": $warnings,
    "deep_path_warnings": $deep_path_warnings,
    "auto_todo_fixes": $auto_todo_fixes,
    "skipped_external_urls": $skipped_external_urls,
    "success_rate": $success_rate
  },
  "broken_links": [
    $(IFS=,; echo "${JSON_BROKEN_LINKS[*]:-}")
  ],
  "warnings": [
    $(IFS=,; echo "${JSON_WARNINGS[*]:-}")
  ],
  "deep_paths": [
    $(IFS=,; echo "${JSON_DEEP_PATHS[*]:-}")
  ]
}
EOF
}

# ============================================================================
# EXIT HANDLING
# ============================================================================

exit_with_status() {
    if [[ $broken_links -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# ============================================================================
# MARKDOWN FILE FINDER
# ============================================================================

find_markdown_files() {
    local area_dir="$1"
    local exclude_dirs="$2"

    if [[ -n "$exclude_dirs" ]]; then
        find "$area_dir" -name "*.md" -type f 2>/dev/null | grep -v "/$exclude_dirs/" | sort
    else
        find "$area_dir" -name "*.md" -type f 2>/dev/null | sort
    fi
}

# ============================================================================
# USAGE MESSAGE (Caller should override show_usage for area-specific help)
# ============================================================================

show_usage() {
    cat <<EOF
Usage: validate-links.sh [OPTIONS]

Validates all Markdown links in the area.

OPTIONS:
    -v, --verbose                Show detailed output for all links
    --no-color                   Disable colored output
    -j N, --parallel-jobs=N      Run N parallel jobs (default: 2)

    OPTIONS:
    --output-format=FORMAT       Output format: text (default) or json
    --fix-pattern=OLD:NEW        Auto-fix links matching OLD pattern to NEW
    --auto-todo                  Mark missing files as TODO (no git history check)
    --no-deep-path-warning       Disable deep path warnings
    --max-path-depth=N           Max ../ levels before warning (default: 5)
    --warm-cache                 Pre-build anchor cache for all files

    -h, --help                   Show this help message

EXAMPLES:
    ./validate-links.sh                            # Basic validation
    ./validate-links.sh -v -j 4                    # Verbose with 4 parallel jobs
    ./validate-links.sh --output-format=json       # JSON output for CI/CD
    ./validate-links.sh --fix-pattern="ref/ops/:ref/ops/emergency/"  # Batch fix
    ./validate-links.sh --auto-todo                # Auto-mark TODO for missing files

EXIT CODES:
    0 - All links valid
    1 - Broken links found
    2 - Script error
EOF
}
