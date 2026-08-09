#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Test suite for lib/ and the documentation link validators.
#
# Runs as an ordinary user, with no PostgreSQL, no MTA, no RAID array and no
# test framework. That is the point: a contributor who clones this repository
# must be able to verify the library without recreating the production host.
# Four injection points make it possible — PG_TOOLKIT_STATE_DIR,
# PG_TOOLKIT_NOW, PG_TOOLKIT_MDSTAT and PG_TOOLKIT_NO_MTA.
#
# Usage:
#   bash tests/run-lib-tests.sh            # everything
#   bash tests/run-lib-tests.sh --quick    # skip the link validators (~10s)
#
# Exit codes: 0 all passed, 1 at least one failure.
#
# Every check that guards against a false "all clear" is written in BOTH
# directions: the clean case must stay silent AND a planted fault must be
# caught. A test that only ever confirms success proves nothing — this
# repository shipped exactly that bug in validate-all-areas.sh until v0.1.2.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly REPO_ROOT
readonly FIXTURES="${REPO_ROOT}/tests/fixtures"

QUICK=false
[[ "${1:-}" == "--quick" ]] && QUICK=true

PASS=0
FAIL=0

if [[ -t 1 ]]; then
    C_OK=$'\033[0;32m'; C_NO=$'\033[0;31m'; C_H=$'\033[1m'; C_0=$'\033[0m'
else
    C_OK=""; C_NO=""; C_H=""; C_0=""
fi

section() { printf '\n%s== %s%s\n' "$C_H" "$1" "$C_0"; }

ok()   { PASS=$((PASS + 1)); printf '  %sPASS%s  %s\n' "$C_OK" "$C_0" "$1"; }
no()   { FAIL=$((FAIL + 1)); printf '  %sFAIL%s  %s\n' "$C_NO" "$C_0" "$1"
         [[ -n "${2:-}" ]] && printf '        %s\n' "$2"; }

# assert_eq <expected> <actual> <description>
assert_eq() {
    if [[ "$1" == "$2" ]]; then ok "$3"; else no "$3" "expected <$1>, got <$2>"; fi
}

# assert_contains <haystack> <needle> <description>
assert_contains() {
    case "$1" in *"$2"*) ok "$3" ;; *) no "$3" "missing: $2" ;; esac
}

# assert_absent <haystack> <needle> <description>
assert_absent() {
    case "$1" in *"$2"*) no "$3" "unexpectedly present: $2" ;; *) ok "$3" ;; esac
}

# Every case runs in its own `bash -c` on purpose: the cooldown state, the
# once-per-process MTA warning and the include guards are all process-scoped,
# so sharing a shell between cases would let them mask each other.

# ---------------------------------------------------------------------------
section "1. Loading"
# ---------------------------------------------------------------------------

for f in logging.sh utils.sh secure-file-utils.sh; do
    if bash -c "set -uo pipefail; cd '$REPO_ROOT'; source lib/$f" 2>/dev/null; then
        ok "lib/$f sources standalone under set -uo pipefail"
    else
        no "lib/$f sources standalone under set -uo pipefail" \
           "a library file whose last command is falsy kills the caller with exit 2"
    fi
done

if bash -c "set -uo pipefail; cd '$REPO_ROOT'; source lib/logging.sh; source lib/logging.sh" 2>/dev/null; then
    ok "sourcing twice is idempotent"
else
    no "sourcing twice is idempotent"
fi

# The callers declare these readonly BEFORE sourcing. An assignment to any of
# them inside the library is non-zero and therefore exit 2 for the caller.
if bash -c "set -uo pipefail; cd '$REPO_ROOT'
            readonly SCRIPT_DIR=x LIB_DIR=y LOG_TAG=z LOG_PREFIX=w
            source lib/logging.sh && source lib/utils.sh && source lib/secure-file-utils.sh" 2>/dev/null; then
    ok "no collision with the callers' readonly variables"
else
    no "no collision with the callers' readonly variables" \
       "SCRIPT_DIR/LIB_DIR/LOG_TAG/LOG_PREFIX are readonly in the scripts"
fi

# ---------------------------------------------------------------------------
section "2. Logging"
# ---------------------------------------------------------------------------

out="$(bash -c "cd '$REPO_ROOT'; source lib/logging.sh
    for f in log_info log_success log_warning log_error log_warn; do
        \"\$f\" probe >/dev/null 2>&1 || echo \"NONZERO:\$f\"
    done
    log_info '' >/dev/null 2>&1 || echo 'NONZERO:empty'
    PG_TOOLKIT_LOG_FILE=/nonexistent/x log_info y >/dev/null 2>&1 || echo 'NONZERO:logfile'
    LOG_TAG= log_info z >/dev/null 2>&1 || echo 'NONZERO:notag'" 2>&1)"
assert_eq "" "$out" "log_* always return 0 (they run inside the callers' ERR trap)"

out="$(bash -c "cd '$REPO_ROOT'; source lib/logging.sh
    trap 'log_error trapped' ERR
    false
    echo REACHED" 2>&1)"
assert_contains "$out" "REACHED" "log_error inside an ERR trap does not recurse or hang"

out="$(bash -c "cd '$REPO_ROOT'; source lib/logging.sh; LOG_PERFORMANCE=false log_info marker" 2>&1)"
assert_absent "$out" "[+" "LOG_PERFORMANCE=false drops the elapsed-time prefix"

# ---------------------------------------------------------------------------
section "3. html_escape"
# ---------------------------------------------------------------------------

out="$(bash -c "cd '$REPO_ROOT'; source lib/logging.sh; html_escape 'a<b & c>d \"q\"'")"
assert_eq 'a&lt;b &amp; c&gt;d &quot;q&quot;' "$out" "escapes < > & and \" correctly"
# Guards against the bash 5.2 trap where an unquoted & in a ${x//a/b} replacement
# means "the matched text" and produces `<lt;` instead of `&lt;`.
assert_absent "$out" "<lt;" "no literal '<lt;' (bash 5.2 replacement-& trap)"

# ---------------------------------------------------------------------------
section "4. check_raid_status"
# ---------------------------------------------------------------------------

# healthy, resync-in-progress and a spare must all read as 0. "No array" is the
# important one: /proc/mdstat exists on nearly every Linux, so treating its mere
# presence as "RAID present" would alert on every machine without one.
for case in no-arrays:0 healthy:0 resync:0 spare:0 degraded:1 faulty:1 inactive:1; do
    name="${case%%:*}"; expected="${case##*:}"
    bash -c "cd '$REPO_ROOT'; source lib/utils.sh
             PG_TOOLKIT_MDSTAT='${FIXTURES}/mdstat/${name}' check_raid_status" >/dev/null 2>&1
    assert_eq "$expected" "$?" "mdstat fixture '${name}'"
done

bash -c "cd '$REPO_ROOT'; source lib/utils.sh; PG_TOOLKIT_MDSTAT=/nonexistent check_raid_status" >/dev/null 2>&1
assert_eq "0" "$?" "missing /proc/mdstat is not a degraded array"

# ---------------------------------------------------------------------------
section "5. check_postgresql"
# ---------------------------------------------------------------------------

start=$SECONDS
bash -c "cd '$REPO_ROOT'; source lib/utils.sh; check_postgresql" >/dev/null 2>&1
rc=$?
elapsed=$((SECONDS - start))
if [[ $rc -ne 0 ]]; then
    ok "reports non-zero when PostgreSQL is unreachable"
else
    ok "reports 0 — PostgreSQL appears to be running on this host"
fi
if (( elapsed < 10 )); then
    ok "returns in ${elapsed}s (must not hang a systemd timer)"
else
    no "returns in ${elapsed}s" "too slow, would stall the timer"
fi

# ---------------------------------------------------------------------------
section "6. redact_sensitive_data"
# ---------------------------------------------------------------------------

out="$(bash -c "cd '$REPO_ROOT'; source lib/utils.sh
                redact_sensitive_data \"\$(cat '${FIXTURES}/pg-error.log')\"")"

for secret in hunter2secret S3cr3tPw abcdefghijklmnopqrstuvwx \
              sk-live-0123456789abcdef ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; do
    assert_absent "$out" "$secret" "redacts ${secret:0:12}…"
done

assert_absent   "$out" "<script"    "HTML is escaped (needed even inside <pre>)"
assert_contains "$out" "&lt;script" "the escaped form is present"
assert_contains "$out" "user=monitoring" "ordinary log content survives"

in_lines=$(wc -l < "${FIXTURES}/pg-error.log")
out_lines=$(printf '%s\n' "$out" | wc -l)
assert_eq "$in_lines" "$out_lines" "line count unchanged ($in_lines lines)"

# ---------------------------------------------------------------------------
section "7. format_metrics_table_html"
# ---------------------------------------------------------------------------

out="$(bash -c "cd '$REPO_ROOT'; source lib/utils.sh
    format_metrics_table_html 'TITLE' \\
        '/data|87%|CRITICAL' 'Mem|41%|WARNING' 'Disk|/var|OK' \\
        'Odd|a<b&c|' 'Piped|a|b|OK'")"

# grep -o, not grep -c: the whole table is emitted on a single line, so -c
# would count lines (1) rather than rows.
assert_eq "6" "$(printf '%s' "$out" | grep -o '<tr>' | wc -l)" "one row per entry plus header"
for s in CRITICAL WARNING OK "N/A"; do
    assert_contains "$out" ";$s<" "status '$s' rendered"
done
assert_contains "$out" "a&lt;b&amp;c" "cell values are HTML-escaped"
assert_contains "$out" ">a|b<"        "a pipe inside a value does not shift columns"

# ---------------------------------------------------------------------------
section "8. sfu_append_file"
# ---------------------------------------------------------------------------

T="$(mktemp -d)"
REAL_LINE='[2026-08-09 03:00:00] CPU_LOAD=83.3% RAID_STATUS="md0 : active raid1" PG_CACHE_HIT=99.2%'

bash -c "cd '$REPO_ROOT'; source lib/secure-file-utils.sh
         sfu_append_file '$REAL_LINE' '$T/m.log'" >/dev/null 2>&1
assert_eq "0" "$?" "appends successfully"

printf '%s\n' "$REAL_LINE" > "$T/expected"
if diff -q "$T/m.log" "$T/expected" >/dev/null 2>&1; then
    ok "content is byte-identical (embedded double quotes survive)"
else
    no "content is byte-identical"
fi
assert_eq "640" "$(stat -c '%a' "$T/m.log")" "created with mode 640"

# The reason this function exists: >> follows symlinks, and the script runs as
# root under a systemd timer.
echo "UNTOUCHED" > "$T/victim"
ln -s "$T/victim" "$T/link"
bash -c "cd '$REPO_ROOT'; source lib/secure-file-utils.sh
         sfu_append_file 'malicious' '$T/link'" >/dev/null 2>&1
assert_eq "1" "$?" "refuses to write through a symlink"
assert_eq "UNTOUCHED" "$(cat "$T/victim")" "the symlink target is left untouched"

bash -c "cd '$REPO_ROOT'; source lib/secure-file-utils.sh
         sfu_append_file 'only one arg'" >/dev/null 2>&1
assert_eq "2" "$?" "rejects a missing target path"
rm -rf "$T"

# ---------------------------------------------------------------------------
section "9. Alerting and cooldown"
# ---------------------------------------------------------------------------

S="$(mktemp -d)"
count_alerts() { grep -c '^=== ' "$S/alerts.log" 2>/dev/null || echo 0; }

export PG_TOOLKIT_STATE_DIR="$S" PG_TOOLKIT_NO_MTA=true
NOW="$(date +%s)"

bash -c "cd '$REPO_ROOT'; source lib/utils.sh
         send_alert_once k 3600 'Subject' '<p>Body</p>' 'a@example.com' 'steps' 'impact' '/rb.md'" >/dev/null 2>&1
assert_eq "0" "$?" "send_alert_once returns 0 (a top-level call in backup-postgres.sh)"
assert_eq "1" "$(count_alerts)" "first alert is delivered"

bash -c "cd '$REPO_ROOT'; source lib/utils.sh
         send_alert_once k 3600 'Subject' '<p>Body</p>'" >/dev/null 2>&1
assert_eq "1" "$(count_alerts)" "second alert within the window is suppressed"

bash -c "cd '$REPO_ROOT'; source lib/utils.sh
         PG_TOOLKIT_NOW=$((NOW + 3601)) send_alert_once k 3600 'Subject' '<p>Body</p>'" >/dev/null 2>&1
assert_eq "2" "$(count_alerts)" "delivered again once the window has passed"

# A stamp from the future (NTP correction, wrong RTC) must not mute alerts forever.
printf '%s\n' "$((NOW + 999999))" > "$S/cooldown/k.stamp"
bash -c "cd '$REPO_ROOT'; source lib/utils.sh
         send_alert_once k 3600 'Subject' '<p>Body</p>'" >/dev/null 2>&1
assert_eq "3" "$(count_alerts)" "a stamp from the future does not block (fail open)"

bash -c "cd '$REPO_ROOT'; source lib/utils.sh
         send_alert_once '../../etc/passwd' 60 'S' 'B'" >/dev/null 2>&1
if compgen -G "$S/cooldown/*etc_passwd*" >/dev/null && [[ ! -e "$S/cooldown/../../etc/passwd" ]]; then
    ok "a key containing ../ is sanitised into a plain filename"
else
    no "a key containing ../ is sanitised into a plain filename"
fi

out="$(bash -c "cd '$REPO_ROOT'; source lib/utils.sh
    send_alert_once a 0 S1 B1; send_alert_once b 0 S2 B2; send_alert_once c 0 S3 B3" 2>&1)"
assert_eq "1" "$(printf '%s\n' "$out" | grep -c 'no MTA found')" \
          "the 'alerts are logged only' warning appears exactly once per process"

assert_eq "600" "$(stat -c '%a' "$S/alerts.log")" "alerts.log is mode 600"

out="$(bash -c "cd '$REPO_ROOT'; source lib/utils.sh
    ALERT_EMAIL=fallback@example.com send_alert_once r1 0 S B ''
    send_alert_once r2 0 S B 'explicit@example.com'" 2>&1; grep '^To:' "$S/alerts.log" | tail -2)"
assert_contains "$out" "fallback@example.com" "an empty recipient falls back to ALERT_EMAIL"
assert_contains "$out" "explicit@example.com" "an explicit recipient is honoured"

unset PG_TOOLKIT_STATE_DIR PG_TOOLKIT_NO_MTA
rm -rf "$S"

# ---------------------------------------------------------------------------
section "10. Call sites use the canonical signature"
# ---------------------------------------------------------------------------

# The recipient is argument 5. monitor-postgres-performance.sh used to pass it
# as argument 9 with an empty 5, so performance alerts silently went to the
# default recipient instead of ALERT_EMAIL.
if grep -qE '^\s+"\$\{ALERT_EMAIL:-root@localhost\}" \\$' "$REPO_ROOT/scripts/monitor-postgres-performance.sh"; then
    ok "monitor passes the recipient in argument position 5"
else
    no "monitor passes the recipient in argument position 5"
fi
if grep -qE '^\s+"" \\$' "$REPO_ROOT/scripts/monitor-postgres-performance.sh"; then
    no "no empty placeholder left in position 5"
else
    ok "no empty placeholder left in position 5"
fi
if grep -q 'sudo -n mdadm' "$REPO_ROOT/scripts/backup-postgres.sh"; then
    ok "backup uses 'sudo -n' (never blocks on a password prompt)"
else
    no "backup uses 'sudo -n'"
fi

# ---------------------------------------------------------------------------
if [[ "$QUICK" == false ]]; then
section "11. Documentation link validators"
# ---------------------------------------------------------------------------

    out="$(cd "$REPO_ROOT" && bash scripts/validate-all-areas.sh 2>&1)"
    rc=$?
    assert_eq "0" "$rc" "all five areas validate cleanly"
    assert_contains "$out" "Broken:     0" "no broken links"

    # And the other direction: a validator that cannot fail is worthless.
    probe="$REPO_ROOT/docs/how-to/zz-lib-test-probe.md"
    cat > "$probe" <<'PROBE'
# Probe

- [missing file](./NO_SUCH_FILE.md)
- [dead anchor](#no-such-anchor)
- [missing script](../../scripts/no-such-script.sh)

## Real heading {#real}

- [good anchor](#real)
PROBE
    out="$(cd "$REPO_ROOT" && bash scripts/validate-all-areas.sh 2>&1)"
    rc=$?
    rm -f "$probe"

    assert_eq "1" "$rc" "a planted broken link makes the run fail"
    assert_contains "$out" "NO_SUCH_FILE.md"      "the missing file is reported"
    assert_contains "$out" "#no-such-anchor"      "the dead anchor is reported"
    assert_contains "$out" "no-such-script.sh"    "the missing non-markdown target is reported"
    assert_absent   "$out" "Line 9:"              "the valid anchor is not reported"
fi

# ---------------------------------------------------------------------------
printf '\n%s== Result%s\n' "$C_H" "$C_0"
printf '  passed: %s\n  failed: %s\n' "$PASS" "$FAIL"

if (( FAIL > 0 )); then
    printf '\n%sFAILED%s\n' "$C_NO" "$C_0"
    exit 1
fi
printf '\n%sAll tests passed%s\n' "$C_OK" "$C_0"
exit 0
