# `lib/` — shared shell library

Sourced by the operational scripts in [`scripts/`](../scripts/). Set
`PG_TOOLKIT_LIB_DIR` to point the scripts at a different implementation.

| File | Provides |
|------|----------|
| `logging.sh` | `log_info`, `log_success`, `log_warning`, `log_error`, `log_warn`, `html_escape` |
| `utils.sh` | `send_alert`, `send_alert_once`, `check_postgresql`, `check_raid_status`, `format_metrics_table_html`, `redact_sensitive_data` |
| `secure-file-utils.sh` | `sfu_append_file` |
| `validate-links-core.sh` | vendored link validator, see below |

The files are sourced, not executed, and therefore carry no executable bit.

## Rules any replacement implementation must follow

These are not style preferences — each one corresponds to a way the calling
scripts break.

1. **End every file with `return 0`.** The callers source with `|| exit 2`, and
   the exit status of `source` is the status of the file's last command. A
   trailing guard that happens to be false aborts the caller with a message that
   explains nothing.
2. **Never assign to `SCRIPT_DIR`, `LIB_DIR`, `LOG_TAG` or `LOG_PREFIX`.** The
   callers declare them `readonly` before sourcing; an assignment is non-zero and
   becomes exit 2. Everything private here is prefixed `_pgt_` / `PG_TOOLKIT_`.
3. **Install no traps and do not touch shell options.** Both scripts have their
   own `EXIT`/`INT`/`TERM` and `ERR` traps, and `backup-postgres.sh` relies on
   its `cleanup` handler to delete the temporary uncompressed dump. No `set -e`,
   no `cd`, no global `IFS` or `umask`.
4. **`log_*`, `send_alert` and `send_alert_once` must always return 0.**
   `send_alert_once` is a top-level command in `backup-postgres.sh`; a non-zero
   return fires the `ERR` trap and reports a failure that did not happen.
   `log_error` runs *inside* that trap, so it must not recurse.
5. **`send_alert_once` takes the recipient as argument 5**, and arguments 6–8
   (steps, impact, runbook) are optional — one call site passes only five.

## Environment

| Variable | Default | Effect |
|----------|---------|--------|
| `PG_TOOLKIT_LIB_DIR` | `scripts/../lib` | where the scripts look for this library |
| `PG_TOOLKIT_STATE_DIR` | see below | cooldown stamps and `alerts.log` |
| `PG_TOOLKIT_LOG_FILE` | *(unset)* | additionally append every log line here |
| `PG_TOOLKIT_SYSLOG` | `false` | also log via `logger(1)` |
| `LOG_PERFORMANCE` | `true` | prefix log lines with elapsed seconds |
| `PG_TOOLKIT_MTA_CMD` | *(unset)* | explicit delivery command, overrides autodetection |
| `PG_TOOLKIT_NO_MTA` | `false` | never attempt delivery (alerts are logged only) |
| `PG_TOOLKIT_ALERT_TIMEOUT` | `30` | seconds for one delivery attempt |
| `PG_TOOLKIT_PG_TIMEOUT` | `5` | seconds for the `pg_isready` probe |
| `PG_TOOLKIT_PG_UNIT` | `postgresql` | systemd unit checked as a fallback |
| `PG_TOOLKIT_MDSTAT` | `/proc/mdstat` | RAID status source |
| `PG_TOOLKIT_REDACT_IPS` | `false` | mask the last two octets of IPv4 addresses |
| `PG_TOOLKIT_SFU_STRICT` | `false` | refuse a world-writable parent directory |
| `PG_TOOLKIT_NOW` | *(unset)* | override the clock (tests only) |
| `ALERT_EMAIL` | `root@localhost` | fallback recipient |

State directory resolution, first match wins: `PG_TOOLKIT_STATE_DIR` →
`/var/lib/pg-toolkit` (as root) → `$XDG_STATE_HOME/pg-toolkit` →
`$HOME/.local/state/pg-toolkit` → `${TMPDIR:-/tmp}/pg-toolkit-$(id -u)`.
`/var/lib`, not `/run`: a 24-hour cooldown has to survive a reboot, or the same
alert fires again after every restart.

## Security model

- **Alerts are never lost silently.** Every alert goes to stderr and to
  `<state_dir>/alerts.log` (mode 0600) *before* any delivery attempt. If no MTA
  is available, that is stated once per process.
- **Cooldown fails open.** No state directory, an unreadable stamp, or a stamp
  from the future (NTP correction, wrong RTC) all result in the alert being
  sent. Suppression only ever happens on positive evidence.
- **The cooldown key is sanitised** before it becomes a filename, so a key
  containing `../` cannot escape the state directory.
- **`sfu_append_file` refuses to follow symlinks.** That is its entire reason
  for existing: `>>` follows them, and the monitor runs as root.
- **`redact_sensitive_data` HTML-escapes its output.** Escaping is required even
  inside `<pre>`, which changes whitespace handling but not parsing.

Note the resulting asymmetry when assembling a mail body:
`format_metrics_table_html` returns markup and must **not** be escaped again;
`redact_sensitive_data` returns text that is already escaped; anything else
still needs `html_escape`.

## What is deliberately not implemented

- No `flock` around the append: a single `printf` into an `O_APPEND` descriptor
  is already atomic below `PIPE_BUF` (4096 bytes).
- No redaction of PEM key bodies (only the `BEGIN` marker) and none of
  `.pgpass`-shaped `host:port:db:user:pass` lines — a generic "fifth colon
  field" pattern matches masses of ordinary PostgreSQL log output.
- No RFC 2047 encoded-words in mail subjects. All current subjects are ASCII.
- IP masking is off by default: in an operational alert, client addresses are
  triage information rather than a leak.

## `validate-links-core.sh`

Vendored on 2026-08-09 from
[bash-markdown-link-validator](https://github.com/fidpa/bash-markdown-link-validator)
v1.2.3 (MIT, same copyright holder), so that a fresh clone can run
`scripts/validate-all-areas.sh` with no external dependency. Two local patches,
marked `PATCH(psql-ai):` in the source, are described in the file header; both
belong upstream. `grep -n 'PATCH(psql-ai)' lib/validate-links-core.sh` lists
them.

## Tests

```bash
bash tests/run-lib-tests.sh          # everything, ~15 s
bash tests/run-lib-tests.sh --quick  # without the link validators
```

Runs as an ordinary user — no PostgreSQL, no MTA, no RAID array, no test
framework. Every check that guards against a false "all clear" is written in
both directions: the clean case must stay silent *and* a planted fault must be
caught.
