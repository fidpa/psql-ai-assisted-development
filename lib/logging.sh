#!/bin/bash
# lib/logging.sh - logging primitives for the operational scripts
# SPDX-License-Identifier: MIT
#
# Sourced by scripts/backup-postgres.sh, scripts/monitor-postgres-performance.sh
# and (optionally, with a built-in fallback) scripts/validate-all-areas.sh.
#
# CONTRACT
#   log_info | log_success | log_warning | log_error   <message>
#   log_warn                                           alias for log_warning
#       One argument, an already-assembled string. Side effects only; the return
#       value is NEVER inspected by the callers and MUST always be 0 — both
#       callers install `trap 'log_error ...' ERR`, so a non-zero return here
#       would either fire the trap or recurse.
#   html_escape <text>          → escaped text on stdout
#   _pgt_now                    → epoch seconds (override: PG_TOOLKIT_NOW)
#   _pgt_state_dir              → writable state directory on stdout
#
# ENVIRONMENT
#   LOG_TAG               set readonly by the caller before sourcing. Read, never
#                         written. Used as the syslog tag.
#   LOG_PERFORMANCE       true (default) → prefix each line with elapsed seconds.
#                         scripts/validate-all-areas.sh exports false.
#   PG_TOOLKIT_LOG_FILE   additionally append every line to this file.
#   PG_TOOLKIT_SYSLOG     true → also send to syslog via logger(1). Default false:
#                         under systemd stdout/stderr already reach the journal,
#                         so the default would duplicate every line.
#   PG_TOOLKIT_STATE_DIR  override for the state directory (test hook).
#   PG_TOOLKIT_NOW        override for the clock (test hook).
#
# RULES OBSERVED HERE (see lib/README.md for the reasoning)
#   - The file ends in `return 0`. Callers source with `|| exit 2`, and the status
#     of `source` is the status of the last command in the file.
#   - No trap, no `set -e`, no `cd`, no global IFS/umask: this runs inside the
#     caller's shell, which has its own EXIT/ERR traps.
#   - Everything private is prefixed `_pgt_`; SCRIPT_DIR, LIB_DIR, LOG_TAG and
#     LOG_PREFIX are readonly in the callers and must never be assigned here.

[[ -n "${_PGT_LOGGING_LOADED:-}" ]] && return 0
_PGT_LOGGING_LOADED=1

# Emitted once per process when the state directory cannot be created.
_PGT_STATE_WARNED=""

# ---------------------------------------------------------------------------
# Clock
# ---------------------------------------------------------------------------

# Epoch seconds. PG_TOOLKIT_NOW lets the test suite move time forward without
# waiting for a real cooldown window to expire.
_pgt_now() {
    if [[ -n "${PG_TOOLKIT_NOW:-}" ]]; then
        printf '%s\n' "$PG_TOOLKIT_NOW"
    else
        date +%s
    fi
}

# ---------------------------------------------------------------------------
# State directory
# ---------------------------------------------------------------------------

# Resolve a directory this process may write to, preferring one that survives a
# reboot: an alert cooldown of 24 hours is worthless in /run, which is cleared at
# boot — the same alert would fire again after every restart.
#
# Prints the path on stdout. Returns 1 if no usable directory exists; callers
# must treat that as "no cooldown" and send the alert anyway (fail open).
_pgt_state_dir() {
    local d uid
    uid="$(id -u)"

    if   [[ -n "${PG_TOOLKIT_STATE_DIR:-}" ]];          then d="$PG_TOOLKIT_STATE_DIR"
    elif [[ "${EUID:-$uid}" -eq 0 ]];                   then d="/var/lib/pg-toolkit"
    elif [[ -n "${XDG_STATE_HOME:-}" ]];                then d="${XDG_STATE_HOME}/pg-toolkit"
    elif [[ -n "${HOME:-}" && -w "${HOME:-/nonexistent}" ]]; then d="${HOME}/.local/state/pg-toolkit"
    else d="${TMPDIR:-/tmp}/pg-toolkit-${uid}"
    fi

    if mkdir -p "$d" 2>/dev/null && [[ -O "$d" && -w "$d" ]]; then
        chmod 700 "$d" 2>/dev/null || true
        printf '%s\n' "$d"
        return 0
    fi

    # Last resort. The UID is part of the name and ownership is verified, so a
    # different user cannot pre-create the path and take over our state.
    d="${TMPDIR:-/tmp}/pg-toolkit-${uid}"
    if mkdir -p "$d" 2>/dev/null && [[ -O "$d" && -w "$d" ]]; then
        chmod 700 "$d" 2>/dev/null || true
        printf '%s\n' "$d"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# HTML escaping
# ---------------------------------------------------------------------------

# Escape text for inclusion in an HTML mail body.
#
# Needed even inside <pre>: that element changes whitespace handling, not
# parsing. A PostgreSQL log line such as `ERROR: syntax error at or near "<"`
# would otherwise break the markup.
#
# The entities are held in variables and expanded QUOTED. Writing them inline as
# `${s//</&lt;}` does not work: since bash 5.2 an unquoted `&` in the replacement
# of ${var//pat/repl} means "the text that matched", so that expression yields
# `<lt;` instead of `&lt;`. Measured on bash 5.2.21 — and an unquoted variable
# holding `&` is rescanned the same way, so the quotes are load-bearing, not
# decoration.
#
# `&` is replaced first; the `&` characters introduced afterwards are not seen
# again because the remaining patterns are `<`, `>` and `"`.
html_escape() {
    local s="${1-}"
    local _amp='&amp;' _lt='&lt;' _gt='&gt;' _quot='&quot;'
    s="${s//&/"$_amp"}"
    s="${s//</"$_lt"}"
    s="${s//>/"$_gt"}"
    s="${s//\"/"$_quot"}"
    printf '%s' "$s"
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

# $1 level, $2 stream (1|2), $3 message. Always returns 0.
_pgt_log_line() {
    local level="${1:-INFO}" stream="${2:-1}" msg="${3-}"
    local stamp prefix=""

    stamp="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" || stamp="?"

    # Elapsed-seconds prefix. $SECONDS is a bash builtin — no fork per line,
    # which matters because the monitor logs ~25 lines per run.
    if [[ "${LOG_PERFORMANCE:-true}" == "true" ]]; then
        prefix="[+${SECONDS}s] "
    fi

    local line="${stamp} [${level}] ${prefix}${msg}"

    if [[ "$stream" == "2" ]]; then
        printf '%s\n' "$line" >&2
    else
        printf '%s\n' "$line"
    fi

    if [[ -n "${PG_TOOLKIT_LOG_FILE:-}" ]]; then
        printf '%s\n' "$line" >> "${PG_TOOLKIT_LOG_FILE}" 2>/dev/null || true
    fi

    if [[ "${PG_TOOLKIT_SYSLOG:-false}" == "true" ]] && command -v logger >/dev/null 2>&1; then
        logger -t "${LOG_TAG:-pg-toolkit}" -p "user.${4:-info}" -- "$msg" 2>/dev/null || true
    fi

    return 0
}

log_info()    { _pgt_log_line "INFO"    1 "${1-}" "info";    return 0; }
log_success() { _pgt_log_line "OK"      1 "${1-}" "info";    return 0; }
log_warning() { _pgt_log_line "WARNING" 2 "${1-}" "warning"; return 0; }
log_error()   { _pgt_log_line "ERROR"   2 "${1-}" "err";     return 0; }

# scripts/validate-all-areas.sh calls log_warn; the other two call log_warning.
# Both names are part of the contract.
log_warn() { log_warning "${1-}"; return 0; }

return 0
