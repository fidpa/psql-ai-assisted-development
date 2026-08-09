#!/bin/bash
# lib/secure-file-utils.sh - guarded file append
# SPDX-License-Identifier: MIT
#
# Sourced by scripts/monitor-postgres-performance.sh.
#
# CONTRACT
#   sfu_append_file <content> <target_file>
#       NOTE THE ARGUMENT ORDER: content first, path second. It is unusual, and
#       the reversed call `sfu_append_file "$file" "$content"` would look
#       plausible while appending the filename to the metrics string. The order
#       is fixed by the existing call site and is not changed here.
#       Returns 0 on success, non-zero on a real failure — that call site is a
#       top-level command, so the caller's ERR trap is meant to fire.
#
# WHY THIS EXISTS AT ALL — what makes it "secure" over `echo >>`
#   `>>` follows symlinks, and this script runs as root under a systemd timer.
#   Anyone able to replace /var/log/performance-metrics.log with a link to, say,
#   /etc/cron.d/x gets a root-owned write of attacker-influenced content. The
#   symlink check below, performed on the path itself (-L, which does not
#   dereference) before the file is ever opened, is the point of the function.
#
# WHAT IS DELIBERATELY *NOT* DONE (and why it would be overhead)
#   - No flock: a single printf into an O_APPEND descriptor is atomic against
#     other appenders as long as it stays under PIPE_BUF (4096 on Linux). A lock
#     would buy nothing and add a failure mode.
#   - No temp file + rename: that breaks append semantics — it forces a
#     read-modify-write of the whole file, which is absurd for a 10,000-line log.
#   - No fsync per metrics line.
#   - No recursive parent-directory audit. The direct parent is checked only
#     under PG_TOOLKIT_SFU_STRICT=true.
#
# ENVIRONMENT
#   PG_TOOLKIT_SFU_STRICT   true → additionally refuse a world-writable parent
#                           directory without a sticky bit. Default false.

[[ -n "${_PGT_SFU_LOADED:-}" ]] && return 0
_PGT_SFU_LOADED=1

# logging.sh may not be loaded when this file is sourced on its own (the test
# suite does exactly that).
if ! declare -F log_error >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    source "${BASH_SOURCE[0]%/*}/logging.sh" || return 1
fi

# Linux PIPE_BUF. Above this an append is no longer guaranteed atomic against
# concurrent writers, so we warn instead of pretending.
_PGT_SFU_ATOMIC_MAX=4096

sfu_append_file() {
    local content="${1-}"
    local target="${2-}"

    if [[ -z "$target" ]]; then
        log_error "sfu_append_file: no target file given (argument order is: content, then path)"
        return 2
    fi

    # Symlink check first, and on the path itself. -f would dereference and
    # happily accept a link pointing at /etc/cron.d/x.
    if [[ -L "$target" ]]; then
        log_error "sfu_append_file: refusing to write through a symlink: $target"
        return 1
    fi

    if [[ -e "$target" && ! -f "$target" ]]; then
        log_error "sfu_append_file: not a regular file: $target"
        return 1
    fi

    local parent="${target%/*}"
    [[ "$parent" == "$target" ]] && parent="."
    if [[ ! -d "$parent" ]]; then
        log_error "sfu_append_file: directory does not exist: $parent"
        return 1
    fi

    if [[ "${PG_TOOLKIT_SFU_STRICT:-false}" == "true" ]]; then
        if [[ -w "$parent" && -k "$parent" ]]; then
            : # sticky bit set, that is the /tmp pattern and acceptable
        elif [[ "$(stat -c '%a' "$parent" 2>/dev/null || echo 000)" == *[2367] ]]; then
            log_error "sfu_append_file: parent directory is world-writable without sticky bit: $parent"
            return 1
        fi
    fi

    # One record per line. Embedded newlines would break the line structure of
    # the metrics log, so they are collapsed rather than silently accepted or
    # rejected — losing a metrics record would be worse than reshaping it.
    if [[ "$content" == *$'\n'* || "$content" == *$'\r'* ]]; then
        log_warning "sfu_append_file: newlines in content collapsed to spaces"
        content="${content//$'\r'/ }"
        content="${content//$'\n'/ }"
    fi

    if (( ${#content} + 1 > _PGT_SFU_ATOMIC_MAX )); then
        log_warning "sfu_append_file: record exceeds ${_PGT_SFU_ATOMIC_MAX} bytes, append is no longer atomic"
    fi

    if [[ ! -e "$target" ]]; then
        if ! (umask 027; : >> "$target") 2>/dev/null; then
            log_error "sfu_append_file: cannot create $target"
            return 1
        fi
        chmod 640 "$target" 2>/dev/null || true
    fi

    # printf, never echo: echo mangles backslashes depending on shell and
    # xpg_echo, and would eat a leading -n/-e. The metrics string contains
    # embedded double quotes and must arrive byte for byte.
    if ! printf '%s\n' "$content" >> "$target" 2>/dev/null; then
        log_error "sfu_append_file: append failed: $target"
        return 1
    fi

    return 0
}

return 0
