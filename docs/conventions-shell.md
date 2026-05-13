# Shell conventions (SSH-triggered workflows)

This repo is designed so that **each SSH call triggers one precise intent** and returns a **standard response** that iPhone Shortcuts can reliably parse.

The iPhone is the UI + validation layer. The Mac is the execution layer.

---

## Principles

- **One action = one intent**: one SSH trigger maps to one script/workflow.
- **No over-validation**: the iPhone Shortcut already validated inputs.
  - Scripts assume local env/config is already correct and should not duplicate config checks.
- **Stable output contract**: stdout is a machine interface for the iPhone.
- **Secrets stay on the Mac**: scripts load secrets locally (env files) and never print them.
- **Fast + deterministic**: scripts should be quick; avoid interactive prompts.

---

## File layout (recommended)

- Workflows grouped by integration:
  - `clickup/`, `git/`, `calendar/`, `messages/`, etc.
- Logs:
  - `vars/logs/<workflow>.log` (see `docs/logging.md`)
- Config:
  - `config/env.sh` (ignored by git)

---

## Inputs

### Arguments

- Use positional args (`$1`, `$2`, …) for the minimal payload.
- Keep them small (titles, IDs, flags). Avoid passing JSON blobs if possible.

### Environment variables

- Load secrets via `source config/env.sh` (local only).
- Prefer explicit names per integration: `CLICKUP_TOKEN`, `CLICKUP_INBOX_ID`, etc.
- Environment values must be canonical and ready to use. Scripts should not normalize or repair them.
  - Example: base URLs have no trailing slash, paths have no leading slash.

---

## Output contract (stdout)

**stdout must be exactly one JSON object on a single line.**

This allows iPhone Shortcuts to parse with “Get Dictionary from Input” reliably.

### Shape (v1)

```json
{
  "status": "SUCCESS" | "ERROR",
  "action": "string",
  "message": "string",
  "data": {}
}
```

Rules:

- **Always include** `status`, `action`, `message`.
- `data` is optional, but recommended for machine-readable fields (ids, urls).
- **Never** print extra lines (no debug `echo`, no banners). Put debug detail into file logs.

### Examples

Success:

```json
{"status":"SUCCESS","action":"create_clickup_task","message":"Task created","data":{"id":"86c9qfzh9","url":"https://app.clickup.com/t/86c9qfzh9"}}
```

Error:

```json
{"status":"ERROR","action":"create_clickup_task","message":"ClickUp API error","data":{"http_code":401}}
```

---

## Exit codes

- Exit code is for UNIX correctness; the iPhone mainly relies on stdout JSON.
- Convention:
  - `0` on success
  - non-zero on failure

Common suggestion:

- `2` missing/invalid input (only minimal checks)
- `3` missing env/secret
- `10` network/API failure
- `20` unexpected error

---

## Error handling

- Scripts should be strict:
  - `set -euo pipefail` is recommended for most workflows.
- On error:
  - Emit the **standard JSON** error on stdout
  - Log short, useful context to `vars/logs/<workflow>.log` (redacted)

---

## Idempotency (when applicable)

For actions that can be re-triggered accidentally (double tap, flaky network):

- Prefer idempotent behavior if possible:
  - Use deterministic keys or detect “already done”
  - Or return a clear “already exists” success

If not possible, ensure the iPhone Shortcut makes retries explicit.

---

## Validation boundary

The iPhone Shortcut is the validation/UI layer, and `config/env.example.sh` documents required local configuration.

Scripts should **not** add environment variable presence checks. They assume the local Mac is configured correctly via `config/env.sh`.

Keep scripts focused on one action, avoid duplicating UI validation, and avoid echoing raw payloads that might contain secrets.

---

## Logging

Use `docs/logging.md` conventions:

- Log one line per outcome
- Keep format stable
- Redact secrets

---

## SSH orchestration note

The design assumes SSH is used as a bridge from a **personal device** (iPhone) to execute workflows that can touch **professional systems**, without installing extra “control surface” hardware.

This makes the stdout contract and secret handling non-negotiable.

