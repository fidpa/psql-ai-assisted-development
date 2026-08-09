#!/bin/bash
# order_processing: Diataxis link-validation orchestrator
# Validates the five Diataxis areas: tutorial, how-to, reference, explanation,
# entry-points.
#
# Tool version (own axis, deliberately not the repository version — see
# CHANGELOG.md for the repository version).
# Version: 1.1.0
# Created:  2025-11-13
# Authorship: see LICENSE (the other scripts in this directory carry no author
# line either; one attribution in one place is enough).
#
# REQUIREMENT — READ BEFORE RUNNING:
#   This script is an *orchestrator*. It calls a per-area validator at
#   docs/<area>/validate-links.sh and aggregates the results. Those per-area
#   validators are NOT shipped with the public release (they were too tied to
#   the original documentation tree to generalise), exactly like the
#   source-table DDL and sql/procedures/. Without them the script exits 2 with
#   an explicit message; it does not pretend to have validated anything.
#   Supply your own validator per area, or use any link checker you prefer.
#
#   Contract for a drop-in validator (docs/<area>/validate-links.sh):
#     - exit 0 when all links are valid, non-zero otherwise
#     - accept --verbose, --no-color and -j N (all optional)
#     - print these aggregate lines verbatim, so this script can parse them:
#         Total files scanned: N
#         Total links found: N
#         Broken links: N
#         Warnings: N
#
# Features:
# - Validates five Diataxis areas: tutorial/, how-to/, reference/,
#   explanation/, entry-points/
# - Optional parallelism (-j N, passed through to each area validator)
# - Aggregated statistics across all areas
# - Coloured summary report
#
# Usage:
#   validate-all-areas.sh [OPTIONS]
#
# OPTIONS:
#   -j N, --parallel-jobs=N Run N parallel jobs per area (default: 1)
#   -v, --verbose           Show detailed output for every link
#   --no-color              Disable coloured output
#   -h, --help              Show this help
#
# EXIT CODES:
#   0 - every area ran and all links are valid
#   1 - at least one area reported broken links OR failed to run
#   2 - script error, or no per-area validator found (see REQUIREMENT above)
#
# EXAMPLES:
#   validate-all-areas.sh            # sequential validation (all areas)
#   validate-all-areas.sh -j 4       # parallel (4 jobs per area)
#   validate-all-areas.sh --verbose  # detailed output
#
# Changelog v1.1.0:
# - An area that fails to run is now a failure. Until v1.0.1 the final verdict
#   looked only at the broken-link counter, so a run in which every single area
#   aborted with exit 127 still printed "All links validated successfully!" and
#   exited 0.
# - Missing per-area validators are detected up front and reported, instead of
#   surfacing as a bare exit 127 per area.
# - Shebang fixed: was /opt/homebrew/bin/bash (macOS-only), which made direct
#   execution fail on every Linux host with "bad interpreter".
#
# Changelog v1.0.1 (2025-11-17):
# - Batch 6 optimisations (variable quoting, error-handling improvements)
#
# Changelog v1.0.0 (2025-11-13):
# - Initial release for Ubuntu Server
# - Validates all Diataxis areas, sequentially or in parallel
# - Aggregated statistics (total broken links, total files)
# - Coloured summary report with exit code
# - Follows the Ubuntu scripting guidelines (set -uo pipefail, logging.sh)

set -uo pipefail  # NO -e: explicit error handling (Ubuntu guidelines)

# ============================================================================
# VERSION & METADATA (DRY Pattern)
# ============================================================================

readonly VERSION="1.1.0"
SCRIPT_NAME="$(basename "$0" .sh)"
readonly SCRIPT_NAME
# NOTE: Using _SCRIPT_PATH to avoid readonly conflict with logging.sh
_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly _SCRIPT_PATH
SCRIPT_DIR="$(dirname "$_SCRIPT_PATH")"
readonly SCRIPT_DIR

# Resolve project root (dynamically from script location - one level up from scripts/)
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly PROJECT_ROOT

# ============================================================================
# CLEANUP TRAP (Defensive Programming)
# ============================================================================

cleanup() {
    # Defensive cleanup - currently no temp files created
    # Future-proof: Add cleanup tasks here if needed
    :
}
trap cleanup EXIT SIGINT SIGTERM

# ============================================================================
# LOGGING INTEGRATION (Ubuntu Guidelines)
# ============================================================================

# Try to load logging.sh (optional, graceful fallback to echo)
LOGGING_LIB="${PROJECT_ROOT}/lib/logging.sh"
if [[ -f "$LOGGING_LIB" ]]; then
    # Disable performance logging for this script
    export LOG_PERFORMANCE=false
    # shellcheck source=/dev/null
    source "$LOGGING_LIB" || {
        echo "WARNING: Failed to load logging.sh, using fallback" >&2
    }
    USE_LOGGING=true
else
    USE_LOGGING=false
fi

# Fallback logging functions (if logging.sh not available)
if [[ "$USE_LOGGING" != "true" ]]; then
    log_info() { echo "[INFO] $*"; }
    log_warn() { echo "[WARN] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }
fi

# ============================================================================
# CONFIGURATION
# ============================================================================

# Docs directory
readonly DOCS_DIR="${PROJECT_ROOT}/docs"
# Note: Validators are called directly from area directories (no central validator script)

# DIATAXIS Areas to validate (in order)
readonly AREAS=(
    "tutorial"
    "how-to"
    "reference"
    "explanation"
    "entry-points"
)

# Options (können via Environment überschrieben werden)
: "${VERBOSE:=false}"
: "${COLOR_OUTPUT:=true}"
: "${PARALLEL_JOBS:=1}"

# ============================================================================
# COLOR CODES (TTY Detection)
# ============================================================================

setup_colors() {
    if [[ $COLOR_OUTPUT == true ]] && [[ -t 1 ]]; then
        readonly GREEN='\033[0;32m'
        readonly RED='\033[0;31m'
        readonly YELLOW='\033[1;33m'
        readonly BLUE='\033[0;34m'
        readonly CYAN='\033[0;36m'
        readonly BOLD='\033[1m'
        readonly NC='\033[0m'
    else
        readonly GREEN="" RED="" YELLOW="" BLUE="" CYAN="" BOLD="" NC=""
    fi
}

# ============================================================================
# GLOBAL COUNTERS
# ============================================================================

declare -i total_areas=0
declare -i successful_areas=0
declare -i failed_areas=0
declare -i total_files=0
declare -i total_links=0
declare -i total_broken=0
declare -i total_warnings=0

# Start time for duration calculation
START_TIME=$(date +%s)
readonly START_TIME

# ============================================================================
# FUNCTIONS
# ============================================================================

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Validiert alle 5 DIATAXIS-Areas (tutorial, how-to, reference, explanation, entry-points).

OPTIONS:
    -j N, --parallel-jobs=N Führe N parallele Jobs pro Area aus (default: 1)
    -v, --verbose           Zeige detaillierte Ausgabe für alle Links
    --no-color              Deaktiviere farbige Ausgabe
    -h, --help              Zeige diese Hilfe
    --version               Zeige Version

EXIT CODES:
    0 - Alle Links in allen Areas valide
    1 - Mindestens 1 Area hat broken links
    2 - Script-Fehler

EXAMPLES:
    $0                # Sequential validation (alle Areas)
    $0 -j 4           # Parallel (4 jobs pro Area)
    $0 --verbose      # Detaillierte Ausgabe

DIATAXIS AREAS:
    - tutorial/       Lern-orientierte Guides
    - how-to/         Problem-orientierte Guides
    - reference/      Informations-orientierte Referenzen
    - explanation/    Versteh-orientierte Explanations
    - entry-points/   Navigations-Hubs

VERSION: $VERSION

EOF
}

show_version() {
    echo "$SCRIPT_NAME v$VERSION"
}

# Validate a single area
# Returns: 0=success, 1=broken links found, 2=error
validate_area() {
    local area="$1"
    local area_index="$2"
    local area_dir="${DOCS_DIR}/${area}"

    # Check if area exists
    if [[ ! -d "$area_dir" ]]; then
        log_warn "Area not found: $area_dir (skipping)"
        return 2
    fi

    echo ""
    echo -e "${BOLD}[AREA $area_index/${#AREAS[@]}] $area/${NC}"

    # Count files in area (for statistics)
    local file_count
    file_count=$(find "$area_dir" -name "*.md" -type f 2>/dev/null | grep -v "/archive/" | wc -l)

    # Build validator command (call wrapper script in area directory)
    local validator_cmd=("${area_dir}/validate-links.sh")

    # Add flags
    if [[ $VERBOSE == true ]]; then
        validator_cmd+=(--verbose)
    fi

    if [[ $COLOR_OUTPUT != true ]]; then
        validator_cmd+=(--no-color)
    fi

    if [[ $PARALLEL_JOBS -gt 1 ]]; then
        validator_cmd+=(-j "$PARALLEL_JOBS")
    fi

    # Run validator and capture output + exit code
    local validator_output
    local validator_exit=0
    validator_output=$("${validator_cmd[@]}" 2>&1) || validator_exit=$?

    # Parse statistics from output
    local area_files=0
    local area_links=0
    local area_broken=0
    local area_warnings=0

    if [[ "$validator_output" =~ "Total files scanned: "([0-9]+) ]]; then
        area_files="${BASH_REMATCH[1]}"
    fi

    if [[ "$validator_output" =~ "Total links found: "([0-9]+) ]]; then
        area_links="${BASH_REMATCH[1]}"
    fi

    if [[ "$validator_output" =~ "Broken links: "([0-9]+) ]]; then
        area_broken="${BASH_REMATCH[1]}"
    fi

    if [[ "$validator_output" =~ "Warnings: "([0-9]+) ]]; then
        area_warnings="${BASH_REMATCH[1]}"
    fi

    # Update global counters
    total_files=$((total_files + area_files))
    total_links=$((total_links + area_links))
    total_broken=$((total_broken + area_broken))
    total_warnings=$((total_warnings + area_warnings))

    # Show result
    if [[ $validator_exit -eq 0 ]]; then
        if [[ $area_warnings -gt 0 ]]; then
            echo -e "  ${YELLOW}⚠${NC}  $area_links links, $area_warnings warnings ($file_count files)"
        else
            echo -e "  ${GREEN}✓${NC}  $area_links links OK, 0 broken ($file_count files)"
        fi
        successful_areas=$((successful_areas + 1))
        return 0
    elif [[ $validator_exit -eq 1 ]]; then
        echo -e "  ${RED}✗${NC}  $area_links links, $area_broken broken ($file_count files)"
        failed_areas=$((failed_areas + 1))

        # Show broken link details (only if not verbose, verbose already shows everything)
        if [[ $VERBOSE != true ]]; then
            echo "$validator_output" | grep -E "(❌|⚠️)" | head -10
            local broken_count
            broken_count=$(echo "$validator_output" | grep -c "❌" || true)
            if [[ $broken_count -gt 10 ]]; then
                echo -e "  ${CYAN}ℹ${NC}  ... and $((broken_count - 10)) more broken links (use --verbose for full output)"
            fi
        fi

        return 1
    else
        log_error "Validator failed for $area (exit code: $validator_exit)"
        failed_areas=$((failed_areas + 1))
        return 2
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                export VERBOSE  # Export for validator
                shift
                ;;
            --no-color)
                COLOR_OUTPUT=false
                export COLOR_OUTPUT  # Export for validator
                shift
                ;;
            -j)
                if [[ -z "${2:-}" ]]; then
                    log_error "-j requires a positive integer"
                    return 2
                fi
                PARALLEL_JOBS="$2"
                if ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ $PARALLEL_JOBS -lt 1 ]]; then
                    log_error "-j requires a positive integer"
                    return 2
                fi
                shift 2
                ;;
            --parallel-jobs=*)
                PARALLEL_JOBS="${1#*=}"
                if ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [[ $PARALLEL_JOBS -lt 1 ]]; then
                    log_error "--parallel-jobs requires a positive integer"
                    return 2
                fi
                shift
                ;;
            --version)
                show_version
                return 0
                ;;
            -h|--help)
                show_usage
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use -h or --help for usage information" >&2
                return 2
                ;;
        esac
    done

    # Setup colors
    setup_colors

    # Preflight: the per-area validators are the actual workers. They are not
    # shipped with the public release (see REQUIREMENT in the file header).
    # Without this check every area aborts with a bare exit 127, which reads
    # like a broken script rather than a missing dependency.
    local missing_validators=()
    local area
    for area in "${AREAS[@]}"; do
        if [[ ! -x "${DOCS_DIR}/${area}/validate-links.sh" ]]; then
            missing_validators+=("docs/${area}/validate-links.sh")
        fi
    done
    if [[ ${#missing_validators[@]} -eq ${#AREAS[@]} ]]; then
        log_error "No per-area validator found — nothing was validated."
        echo "" >&2
        echo "This script orchestrates per-area validators that are not shipped" >&2
        echo "with the public release. Expected (executable):" >&2
        printf '  %s\n' "${missing_validators[@]}" >&2
        echo "" >&2
        echo "See the REQUIREMENT block at the top of this file for the contract" >&2
        echo "a drop-in validator has to satisfy." >&2
        return 2
    elif [[ ${#missing_validators[@]} -gt 0 ]]; then
        log_warn "Missing validators (these areas will be reported as failed):"
        printf '  %s\n' "${missing_validators[@]}" >&2
    fi

    # Header
    echo -e "${BOLD}${BLUE}============================================="
    echo -e " DIATAXIS Link Validation Report"
    echo -e "=============================================${NC}"
    echo -e "Docs directory: $DOCS_DIR"
    echo -e "Areas: ${#AREAS[@]} (${AREAS[*]})"
    if [[ $PARALLEL_JOBS -gt 1 ]]; then
        echo -e "Parallel jobs: $PARALLEL_JOBS per area"
    else
        echo -e "Mode: Sequential"
    fi

    # Validate each area
    total_areas=${#AREAS[@]}
    local area_index=0
    for area in "${AREAS[@]}"; do
        area_index=$((area_index + 1))

        # Explicit error handling (NO set -e)
        validate_area "$area" "$area_index" || true
    done

    # Calculate duration
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    # ============================================================================
    # SUMMARY REPORT
    # ============================================================================

    echo ""
    echo -e "${BOLD}${BLUE}============================================="
    echo -e " Summary"
    echo -e "=============================================${NC}"

    echo -e "${BOLD}Areas:${NC}"
    echo -e "  Total:      $total_areas"
    echo -e "  Success:    $successful_areas"
    echo -e "  Failed:     $failed_areas"

    echo ""
    echo -e "${BOLD}Files & Links:${NC}"
    echo -e "  Files:      $total_files"
    echo -e "  Links:      $total_links"
    echo -e "  Broken:     $total_broken"
    echo -e "  Warnings:   $total_warnings"

    # Calculate success rate
    if [[ $total_links -gt 0 ]]; then
        local valid_links=$((total_links - total_broken))
        local success_rate=$(( (valid_links * 100) / total_links ))
        echo -e "  Success:    ${success_rate}%"
    fi

    echo ""
    echo -e "${BOLD}Duration:${NC} ${duration}s"
    echo ""

    # Final status.
    # An area that never ran is a failure, not a success. Until v1.0.1 this
    # branch looked at $total_broken alone: a run in which all five areas
    # aborted with exit 127 reported "All links validated successfully!" and
    # exited 0, because a validator that never runs also never finds a broken
    # link. The failure counter is checked first for exactly that reason.
    if [[ $failed_areas -gt 0 && $total_broken -eq 0 ]]; then
        echo -e "${RED}❌ $failed_areas of $total_areas areas did not run — nothing was validated there${NC}"
        echo ""
        echo -e "${CYAN}TIP:${NC} Run with --verbose to see the validator output"
        return 1
    fi

    if [[ $total_broken -eq 0 ]]; then
        if [[ $total_warnings -gt 0 ]]; then
            echo -e "${YELLOW}⚠️  All links valid, but $total_warnings warnings found${NC}"
            return 0
        else
            echo -e "${GREEN}✅ All links validated successfully!${NC}"
            return 0
        fi
    else
        echo -e "${RED}❌ Found $total_broken broken links across $failed_areas areas${NC}"
        echo ""
        echo -e "${CYAN}TIP:${NC} Run with --verbose to see all broken links"
        echo -e "${CYAN}TIP:${NC} Run orchestrator: scripts/validate-all-areas.sh --verbose"
        echo -e "${CYAN}TIP:${NC} Run individual area: cd ${DOCS_DIR}/<area> && ./validate-links.sh"
        return 1
    fi
}

# Run main function only if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
