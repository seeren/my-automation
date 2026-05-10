# Logging

This repo is triggered remotely (iPhone Shortcuts → SSH → macOS → shell scripts). Logging is the main way to understand **what executed**, **when**, and **with what outcome**, without adding UI friction.

---

## Goals

- **Traceability**: every SSH-triggered action should produce a log line (start/end + outcome).
- **Debuggability**: enough detail to troubleshoot failures quickly.
- **Safety**: never leak secrets to logs (tokens, auth headers, personal data).
- **Parsability**: consistent formatting for grep/filters/highlighting.

---

## Where logs live

- Logs are written under `logs/`.
- Log files are ignored by git (`logs/*.log`), so they stay local to the Mac.

Recommended convention:

- One file per workflow: `logs/<workflow>.log`
  - Example: `logs/clickup.log`

---

## Log format (file logs)

Use a single line per event using a pipe-separated format:

```
TIMESTAMP|LEVEL|ACTION|CODE|INPUT|DETAILS
```

- **TIMESTAMP**: ISO-8601 (`date -Iseconds`)
- **LEVEL**: `INFO` or `ERROR` (optionally `WARN`, `DEBUG` later)
- **ACTION**: stable identifier (`create_clickup_task`, `git_commit`, `meeting_create`, etc.)
- **CODE**: integer exit code or HTTP status code (if applicable)
- **INPUT**: short human-readable input (redacted/truncated if needed)
- **DETAILS**: compact detail string or JSON (redacted/truncated)

### Example

```
2026-05-10T16:36:22+02:00|INFO|create_clickup_task|200|title="Exécution"|clickup_task_id=86c9qfzh9
```

---

## What to log (minimum)

For each SSH-triggered workflow:

- **Start line** (optional but helpful):
  - `...|INFO|<action>|0|...|start`
- **End line**:
  - On success: `...|INFO|<action>|<code>|...|success`
  - On failure: `...|ERROR|<action>|<code>|...|<error_summary>`

If you call external APIs:

- Log the **HTTP status code**
- Log a **short error summary** (not the entire response body by default)
- Optionally log a **correlation id** or extracted `id` fields on success

---

## What NOT to log

- Tokens / credentials (env vars like `*_TOKEN`, `*_KEY`, `Authorization:` headers)
- Full request/response bodies if they can contain sensitive data
- Anything the iPhone user wouldn’t want stored locally long-term

### Redaction rules (recommended)

- Replace secrets with `***`
- Truncate large payloads (e.g. 2–4 KB max)
- Prefer extracted fields:
  - `task_id=...`, `url=...`, `error="..."` over dumping full JSON

---

## Standard output vs file logs

This repo has two outputs:

- **stdout**: the response returned over SSH to the iPhone Shortcut
  - Must be **short, stable, machine-readable** (see `docs/conventions-shell.md`)
- **file logs** (`logs/*.log`): deeper local trace for debugging

Rule of thumb:

- stdout: “What should the iPhone do next?”
- file log: “What happened and why?”

---

## Tooling (VS Code / Cursor)

Recommended extensions:

- `emilast.logfilehighlighter` for log readability
- Keep logs parsable with the pipe-separated format to benefit from highlighting/filters

---

## Rotation / cleanup (recommended)

Because logs can grow indefinitely:

- Prefer simple local rotation:
  - Keep last \(N\) days, or last \(M\) MB per file
- Add a periodic cleanup script later (cron/launchd), e.g.:
  - delete logs older than 30 days
  - gzip older logs

Keep this local and simple; the repo is meant to stay lightweight.

