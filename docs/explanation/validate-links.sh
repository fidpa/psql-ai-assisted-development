#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Per-area link validator for docs/explanation/.
#
# Called by scripts/validate-all-areas.sh, which aggregates the results of all
# five Diataxis areas. Can also be run on its own from anywhere.
#
# Contract expected by the orchestrator (see that script's header):
#   flags     --verbose, --no-color, -j N
#   output    "Total files scanned: N", "Total links found: N",
#             "Broken links: N", "Warnings: N"; broken-link detail lines carry
#             an X emoji, warnings a warning sign
#   exit      0 = all links valid, 1 = broken links found, 2 = script error
#
# The work is done by lib/validate-links-core.sh; this file only supplies the
# configuration. Keep the five wrappers identical except for AREA_NAME.

set -uo pipefail

# shellcheck disable=SC2034  # AREA_NAME, DOCS_DIR and EXCLUDE_DIRS are read by
# lib/validate-links-core.sh after it is sourced below.
AREA_NAME="explanation"
EXCLUDE_DIRS="archive|deprecated"

AREA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly AREA_DIR
PROJECT_ROOT="$(cd "$AREA_DIR/../.." && pwd -P)"
readonly PROJECT_ROOT
DOCS_DIR="$PROJECT_ROOT/docs"
# shellcheck disable=SC2034  # read by the sourced library
readonly DOCS_DIR

LIBRARY_PATH="$PROJECT_ROOT/lib/validate-links-core.sh"
if [[ ! -r "$LIBRARY_PATH" ]]; then
    echo "ERROR: cannot find the validation library at: $LIBRARY_PATH" >&2
    exit 2
fi

# shellcheck source=/dev/null
source "$LIBRARY_PATH" || {
    echo "ERROR: failed to load $LIBRARY_PATH" >&2
    exit 2
}

parse_args "$@"
setup_colors
print_validation_header

mapfile -t md_files < <(find_markdown_files "$AREA_DIR" "$EXCLUDE_DIRS")

if [[ ${#md_files[@]} -eq 0 ]]; then
    echo "No markdown files found in $AREA_DIR"
    exit 0
fi

if [[ $PARALLEL_JOBS -eq 1 ]]; then
    validate_sequential "${md_files[@]}"
else
    validate_parallel "${md_files[@]}"
fi

print_summary_report
exit_with_status
