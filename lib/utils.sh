#!/bin/bash
# lib/utils.sh - health checks, alerting, HTML formatting, redaction
# SPDX-License-Identifier: MIT
#
# Sourced by scripts/backup-postgres.sh and scripts/monitor-postgres-performance.sh.
#
# CONTRACT
#   send_alert       <subject> <body> <recipient>
#   send_alert_once  <key> <cooldown_seconds> <subject> <body_html> \
#                    [recipient] [action_steps] [impact] [runbook_path]
#       Both ALWAYS return 0. send_alert_once is a top-level command in
#       backup-postgres.sh, and every caller has `trap ... ERR` installed: a
#       non-zero return would report a script failure that did not happen.
#       Arguments 6-8 are optional; one call site passes only five.
#   check_postgresql                 → exit status, 0 = usable
#   check_raid_status                → exit status, 0 = healthy or not applicable
#   format_metrics_table_html <TITLE> <"Label|Value|STATUS"> ...  → HTML on stdout
#   redact_sensitive_data <text>     → redacted AND html-escaped text on stdout
#
# ESCAPING ASYMMETRY — read this before touching a mail body
#   format_metrics_table_html returns markup and must NOT be escaped again.
#   redact_sensitive_data returns text that is ALREADY escaped.
#   Everything else interpolated into a body still needs html_escape.
#
# ENVIRONMENT
#   ALERT_EMAIL              fallback recipient (default root@localhost)
#   PG_TOOLKIT_MTA_CMD       explicit delivery command, overrides autodetection
#   PG_TOOLKIT_NO_MTA        true → never attempt delivery (test hook)
#   PG_TOOLKIT_ALERT_TIMEOUT seconds for one delivery attempt (default 30)
#   PG_TOOLKIT_PG_TIMEOUT    seconds for the pg_isready probe (default 5)
#   PG_TOOLKIT_PG_UNIT       systemd unit name (default postgresql)
#   PG_TOOLKIT_MDSTAT        path to mdstat (default /proc/mdstat, test hook)
#   PG_TOOLKIT_REDACT_IPS    true → mask the last two octets of IPv4 addresses
#   PG_TOOLKIT_STATE_DIR     see lib/logging.sh

[[ -n "${_PGT_UTILS_LOADED:-}" ]] && return 0
_PGT_UTILS_LOADED=1

if ! declare -F log_error >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    source "${BASH_SOURCE[0]%/*}/logging.sh" || return 1
fi

_PGT_MTA_WARNED=""

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

# timeout(1) is coreutils and practically always present, but the library must
# not fall over if it is not.
_pgt_timeout() {
    local secs="$1"; shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$secs" "$@"
    else
        "$@"
    fi
}

# ---------------------------------------------------------------------------
# Health checks
# ---------------------------------------------------------------------------

# 0 = PostgreSQL is up and accepting connections.
#
# Probe order matters. pg_isready comes first because it measures the functional
# truth and needs no root. systemctl is deliberately NOT first: on Debian and
# Ubuntu `postgresql.service` is a wrapper unit that stays `active (exited)`
# forever, so `systemctl is-active postgresql` still reports success after
# postgresql@16-main has crashed — precisely the situation backup-postgres.sh
# wants to alert on.
check_postgresql() {
    if command -v pg_isready >/dev/null 2>&1; then
        pg_isready -q -t "${PG_TOOLKIT_PG_TIMEOUT:-5}" >/dev/null 2>&1
        case $? in
            0) return 0 ;;   # accepting connections
            1) return 1 ;;   # rejecting (starting up, shutting down, recovery)
            2) return 1 ;;   # no response
            *) : ;;          # 3 = bad invocation, fall through
        esac
    fi

    if [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null 2>&1; then
        if _pgt_timeout 5 systemctl is-active --quiet "${PG_TOOLKIT_PG_UNIT:-postgresql}" 2>/dev/null; then
            return 0
        fi
        return 1
    fi

    pgrep -x postgres    >/dev/null 2>&1 && return 0
    pgrep -x postmaster  >/dev/null 2>&1 && return 0
    return 1
}

# 0 = healthy OR no array configured. Non-zero = degraded.
#
# "No RAID" must never read as "degraded": /proc/mdstat exists on virtually every
# Linux, array or not, so its mere presence proves nothing. The distinguishing
# feature is an array line (`md0 : active raid1 ...`).
#
# A running resync on a complete bitmap is NOT degraded — no device is missing,
# the array is redundant-and-busy. A spare marker (S) is not degraded either.
check_raid_status() {
    local mdstat="${PG_TOOLKIT_MDSTAT:-/proc/mdstat}"
    local rc=0

    [[ -r "$mdstat" ]] || return 0
    grep -qE '^md[0-9]+[[:space:]]*:' "$mdstat" 2>/dev/null || return 0

    # Member bitmap with a hole: [UU_U]. The [U_] character class cannot match
    # the other bracketed fields in mdstat — [raid1] has lowercase letters,
    # [0]/[1] only digits, a resync bar [===>....] only = > and dots.
    grep -qE '\[[U_]*_[U_]*\]' "$mdstat" 2>/dev/null && rc=1

    # Device flagged faulty: nvme0n1p2[1](F)
    grep -qE '\(F\)' "$mdstat" 2>/dev/null && rc=1

    # Inactive array
    grep -qE '^md[0-9]+[[:space:]]*:[[:space:]]*inactive' "$mdstat" 2>/dev/null && rc=1

    # [n/m] with fewer active than expected devices
    local want have
    while read -r want have; do
        [[ "$want" =~ ^[0-9]+$ && "$have" =~ ^[0-9]+$ ]] || continue
        (( have < want )) && rc=1
    done < <(grep -oE '\[[0-9]+/[0-9]+\]' "$mdstat" 2>/dev/null | tr -d '[]' | awk -F/ '{print $1, $2}')

    return "$rc"
}

# ---------------------------------------------------------------------------
# Redaction
# ---------------------------------------------------------------------------

# Case-insensitive keyword list written as explicit character classes on purpose:
# the sed `I` flag is a GNU/BSD portability trap.
_PGT_REDACT_KW='[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Pp][Aa][Ss][Ss][Ww][Dd]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Tt][Oo][Kk][Ee][Nn]|[Aa][Pp][Ii][-_]?[Kk][Ee][Yy]'

# Redact credentials from text, then HTML-escape it.
#
# Order matters: redact first, escape second. The other way round a `"` would
# already be &quot; and the quoted-value patterns below would no longer match.
#
# The output is meant for <pre> in an alert mail. Escaping is required there too
# — <pre> changes whitespace handling, not parsing.
#
# Not handled on purpose: the body of a PEM block (only the BEGIN marker is
# replaced) and .pgpass-style `host:port:db:user:pass` lines. A generic
# "fifth colon field" pattern matches masses of ordinary PostgreSQL log content
# (timestamps, `LOG:  duration: 1.2 ms`) and would be worse than useless.
redact_sensitive_data() {
    local text="${1-}" out

    out="$(printf '%s\n' "$text" | sed -E \
        -e "s/([A-Za-z0-9_.-]*(${_PGT_REDACT_KW}))[[:space:]]*[:=][[:space:]]*(\"[^\"]*\"|'[^']*'|[^[:space:];,\")]*)/\1=[REDACTED]/g" \
        -e 's/(PGPASSFILE|PGSERVICEFILE|PGSSLKEY)[[:space:]]*=[[:space:]]*[^[:space:]]+/\1=[REDACTED-PATH]/g' \
        -e 's#([A-Za-z][A-Za-z0-9+.-]*://[^:/?#[:space:]@]+):[^@[:space:]]+@#\1:[REDACTED]@#g' \
        -e 's/([Bb][Ee][Aa][Rr][Ee][Rr][[:space:]]+)[A-Za-z0-9._~+/=-]{8,}/\1[REDACTED]/g' \
        -e 's/eyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9._-]{10,}/[REDACTED-JWT]/g' \
        -e 's/AKIA[0-9A-Z]{16}/[REDACTED-AWS-KEY]/g' \
        -e 's/xox[abprs]-[A-Za-z0-9-]{10,}/[REDACTED-SLACK-TOKEN]/g' \
        -e 's/gh[pousr]_[A-Za-z0-9]{20,}/[REDACTED-GH-TOKEN]/g' \
        -e 's/-----BEGIN[^-]*PRIVATE KEY-----/[REDACTED-PRIVATE-KEY-BEGIN]/g' \
    )" || out="$text"

    if [[ "${PG_TOOLKIT_REDACT_IPS:-false}" == "true" ]]; then
        out="$(printf '%s\n' "$out" | sed -E 's/\b([0-9]{1,3})\.([0-9]{1,3})\.[0-9]{1,3}\.[0-9]{1,3}\b/\1.\2.x.x/g')"
    fi

    html_escape "$out"
}

# ---------------------------------------------------------------------------
# HTML metrics table
# ---------------------------------------------------------------------------

_PGT_TD_STYLE='padding:6px 10px;border-bottom:1px solid #d8dee4;font-size:13px;'

# format_metrics_table_html <TITLE> <"Label|Value|STATUS"> ...
#
# Inline styles plus the old table attributes, because Outlook's Word renderer
# ignores part of the CSS and falls back to them.
#
# Status is never carried by colour alone — symbol, text, colour and weight all
# encode it. Roughly 8% of men cannot separate the red from the green, and some
# clients strip inline colours entirely.
format_metrics_table_html() {
    local title="${1-Metrics}"
    shift || true

    printf '%s' "<table role=\"presentation\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\" style=\"border-collapse:collapse;width:100%%;max-width:640px;font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;margin:12px 0;\">"
    printf '%s' "<tr><th colspan=\"3\" style=\"text-align:left;padding:8px 10px;background:#24292f;color:#ffffff;font-size:13px;letter-spacing:.04em;\">$(html_escape "$title")</th></tr>"

    local row label value status colour bg weight symbol
    for row in "$@"; do
        # Label is everything before the FIRST pipe, status everything after the
        # LAST one, value the remainder. A pipe inside the value (command output)
        # therefore does not shift the columns.
        if [[ "$row" == *'|'*'|'* ]]; then
            label="${row%%|*}"
            status="${row##*|}"
            value="${row#*|}"
            value="${value%|*}"
        else
            label="$row"
            value=""
            status="N/A"
        fi

        status="$(printf '%s' "$status" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')"
        case "$status" in
            OK)       colour='#1a7f37'; bg='#e9f7ee'; weight='400'; symbol='&#10003;' ;;
            WARNING)  colour='#9a6700'; bg='#fff8e1'; weight='600'; symbol='&#9888;'  ;;
            CRITICAL) colour='#b42318'; bg='#fdeceb'; weight='700'; symbol='&#10006;' ;;
            *)        status='N/A'; colour='#57606a'; bg='#f6f8fa'; weight='400'; symbol='&#8210;' ;;
        esac

        printf '%s' "<tr><td style=\"${_PGT_TD_STYLE}color:#24292f;\">$(html_escape "$label")</td>"
        printf '%s' "<td style=\"${_PGT_TD_STYLE}text-align:right;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;\">$(html_escape "$value")</td>"
        printf '%s' "<td style=\"${_PGT_TD_STYLE}background:${bg};color:${colour};font-weight:${weight};white-space:nowrap;\">${symbol}&nbsp;${status}</td></tr>"
    done

    printf '%s\n' "</table>"
    return 0
}

# ---------------------------------------------------------------------------
# Alert delivery
# ---------------------------------------------------------------------------

_pgt_alert_log() {
    local dir
    if dir="$(_pgt_state_dir)"; then
        printf '%s\n' "${dir}/alerts.log"
        return 0
    fi
    return 1
}

# Crude HTML → text for the `mail` path, which sends text/plain.
_pgt_html_to_text() {
    sed -e 's/<br[^>]*>/\n/g' -e 's/<\/\(p\|tr\|div\|pre\)>/\n/g' -e 's/<[^>]*>//g' \
        -e 's/&nbsp;/ /g' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e 's/&amp;/\&/g'
}

# Deliver one alert. Always returns 0 — see the contract note at the top.
_pgt_deliver() {
    local subject="$1" body_html="$2" recipient="$3"
    local logfile timeout_s="${PG_TOOLKIT_ALERT_TIMEOUT:-30}"

    # Record first, deliver second. The log is the guarantee that nothing is
    # lost silently, so it must not depend on the MTA working.
    printf '%s\n' "=== $(date '+%Y-%m-%d %H:%M:%S') to=${recipient} subject=${subject}" >&2
    if logfile="$(_pgt_alert_log)"; then
        {
            printf '=== %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
            printf 'To: %s\nSubject: %s\n\n' "$recipient" "$subject"
            printf '%s\n\n' "$body_html"
        } >> "$logfile" 2>/dev/null || true
        chmod 600 "$logfile" 2>/dev/null || true
    fi

    # PG_TOOLKIT_NO_MTA joins the "no MTA available" branch below rather than
    # returning early. Both situations end the same way — the alert exists only
    # in the log — and saying so once per process is the honest report. It also
    # makes that branch reachable on a host that does have sendmail, which is
    # the only way the test suite can cover it.
    if [[ "${PG_TOOLKIT_NO_MTA:-false}" != "true" ]]; then

    if [[ -n "${PG_TOOLKIT_MTA_CMD:-}" ]]; then
        if ! printf '%s\n' "$body_html" | _pgt_timeout "$timeout_s" \
                ${PG_TOOLKIT_MTA_CMD} "$subject" "$recipient" >/dev/null 2>&1; then
            log_error "alert delivery via PG_TOOLKIT_MTA_CMD failed (alert is in ${logfile:-stderr})"
        fi
        return 0
    fi

    local sendmail_bin=""
    if command -v sendmail >/dev/null 2>&1; then
        sendmail_bin="$(command -v sendmail)"
    elif [[ -x /usr/sbin/sendmail ]]; then
        # Not on a non-root PATH as a rule, but present on most hosts.
        sendmail_bin="/usr/sbin/sendmail"
    fi

    if [[ -n "$sendmail_bin" ]]; then
        if ! _pgt_timeout "$timeout_s" "$sendmail_bin" -t <<EOF >/dev/null 2>&1
To: ${recipient}
Subject: ${subject}
MIME-Version: 1.0
Content-Type: text/html; charset=UTF-8

${body_html}
EOF
        then
            log_error "sendmail delivery failed or timed out (alert is in ${logfile:-stderr})"
        fi
        return 0
    fi

    if command -v mail >/dev/null 2>&1; then
        # mail(1) sends text/plain; a raw HTML blob would be unreadable, so the
        # body is flattened. Setting a Content-Type header here is bsd-mailx
        # specific and breaks with s-nail and mailutils.
        if ! printf '%s\n' "$body_html" | _pgt_html_to_text \
                | _pgt_timeout "$timeout_s" mail -s "$subject" "$recipient" >/dev/null 2>&1; then
            log_error "mail delivery failed or timed out (alert is in ${logfile:-stderr})"
        fi
        return 0
    fi

    fi  # end of "delivery not disabled"

    if [[ -z "$_PGT_MTA_WARNED" ]]; then
        _PGT_MTA_WARNED=1
        log_warning "mail delivery disabled or no MTA found (sendmail/mail) — alerts are logged only, see ${logfile:-stderr}"
    fi
    return 0
}

# Assemble the optional sections into one body.
_pgt_build_body() {
    local body="$1" steps="${2-}" impact="${3-}" runbook="${4-}"
    printf '%s' "$body"
    [[ -n "$steps" ]]   && printf '\n\n<strong>Suggested actions:</strong>\n<pre>%s</pre>' "$(html_escape "$steps")"
    [[ -n "$impact" ]]  && printf '\n\n<strong>Impact:</strong>\n<pre>%s</pre>' "$(html_escape "$impact")"
    [[ -n "$runbook" ]] && printf '\n\n<strong>Runbook:</strong> %s' "$(html_escape "$runbook")"
    printf '\n'
    return 0
}

# send_alert <subject> <body> <recipient>
send_alert() {
    local subject="${1-(no subject)}" body="${2-}" recipient="${3-}"
    [[ -z "$recipient" ]] && recipient="${ALERT_EMAIL:-root@localhost}"
    _pgt_deliver "$subject" "$body" "$recipient"
    return 0
}

# Is the cooldown for this stamp still running? 0 = suppress.
_pgt_cooldown_active() {
    local stamp="$1" cooldown="$2" now last

    [[ "$cooldown" =~ ^[0-9]+$ ]] || return 1
    (( cooldown == 0 )) && return 1
    [[ -f "$stamp" ]] || return 1

    read -r last < "$stamp" 2>/dev/null || return 1
    [[ "$last" =~ ^[0-9]+$ ]] || return 1

    now="$(_pgt_now)"
    # A stamp from the future (NTP correction, wrong RTC) must not block the
    # alert forever.
    (( last > now )) && return 1
    (( now - last < cooldown )) && return 0
    return 1
}

# send_alert_once <key> <cooldown_s> <subject> <body_html> [recipient] [steps] [impact] [runbook]
send_alert_once() {
    local key="${1-alert}" cooldown="${2-0}" subject="${3-(no subject)}" body="${4-}"
    local recipient="${5-}" steps="${6-}" impact="${7-}" runbook="${8-}"

    [[ -z "$recipient" ]] && recipient="${ALERT_EMAIL:-root@localhost}"

    # The key becomes a filename.
    local safe_key="${key//[^A-Za-z0-9_.-]/_}"
    [[ -z "$safe_key" ]] && safe_key="alert"
    [[ "$safe_key" == .* ]] && safe_key="key_${safe_key#.}"

    local dir stamp=""
    if dir="$(_pgt_state_dir)"; then
        mkdir -p "${dir}/cooldown" 2>/dev/null || true
        stamp="${dir}/cooldown/${safe_key}.stamp"
    fi

    # No state directory → no cooldown, but the alert still goes out. A state
    # directory that cannot be created must never suppress alerts.
    if [[ -n "$stamp" ]] && _pgt_cooldown_active "$stamp" "$cooldown"; then
        log_info "alert '${safe_key}' suppressed (cooldown ${cooldown}s still active)"
        return 0
    fi

    # Stamp before delivery, so a hung or crashing MTA cannot turn into an alert
    # loop on the next run.
    if [[ -n "$stamp" ]]; then
        if printf '%s\n' "$(_pgt_now)" > "${stamp}.tmp" 2>/dev/null; then
            mv -f "${stamp}.tmp" "$stamp" 2>/dev/null || rm -f "${stamp}.tmp" 2>/dev/null
        fi
    fi

    local full_body
    full_body="$(_pgt_build_body "$body" "$steps" "$impact" "$runbook")"
    _pgt_deliver "$subject" "$full_body" "$recipient"
    return 0
}

return 0
