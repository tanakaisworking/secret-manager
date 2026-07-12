---
name: secret-manager
description: Use whenever an AI coding assistant such as Claude Code, Codex, Cursor, or another local assistant needs any real value that should not be pasted into chat: API keys, access tokens, refresh tokens, PATs, service role keys, JWTs, OAuth client secrets, webhook signing secrets, passwords, database URLs with credentials, SSH/private keys, recovery codes, one-time credentials, vendor/client credentials, or any pasted-looking credential even when the prefix is unknown. Trigger on phrasing such as "secret", "API key", "token", "password", "シークレット", "鍵", "認証情報", "これ使って", "渡すよ", or "ログイン情報" when the value grants account or service access. The user should tell the assistant only the secret name and destination, never the value. Open a visible local terminal so the user can verify the exact command and enter the value outside chat. Do not use for general security discussion, secret scanning, public IDs, environment variable names without values, or non-secret configuration.
metadata:
  version: "0.6.1"
  compatibility: Local macOS with Terminal.app and osascript for bundled scripts; the workflow is assistant-agnostic and can be followed by Claude Code, Codex, Cursor, or similar local coding assistants.
---

# Secret Manager

The core contract: the assistant may know the secret name, destination command, and project path; the assistant must not know the secret value.

Use the smallest safe path. If the target CLI already prompts securely, just
open that prompt in a visible terminal. If the assistant needs the value only to
run one local command, use the terminal as the one-time input vessel with
`run-with-secret.sh`. Store secrets only when the user explicitly wants reuse.

## Trigger Rule

Use this skill by category, not by a fixed prefix list. If the value would let
someone log in, call an API, deploy, access a database, impersonate a user, sign
webhooks, or recover an account, it must not enter chat.

Trigger examples include:

- API keys, access tokens, refresh tokens, PATs, service role keys, JWTs, OAuth
  client secrets, webhook signing secrets, passwords, database URLs with
  credentials, SSH/private keys, recovery codes, and one-time credentials.
- User wording like "secret", "API key", "token", "password", "シークレット",
  "鍵", "認証情報", "これ使って", "渡すよ", or "ログイン情報" when the value grants
  access.
- Any pasted-looking credential, even if the prefix is unfamiliar.

Do not trigger for public project IDs, public URLs, environment variable names
without values, or general security discussion where no secret value is needed.

## Rules

1. Never ask the user to paste a secret value into chat.
2. Never put a secret value in command arguments, heredocs, temp files, logs, or agent-visible output.
3. The assistant may handle non-secret metadata: secret name, service name, account name, working directory, and target command.
4. Show the user the destination command before value entry.
5. Prefer platform CLIs that accept a secret name and prompt for the value, such as `wrangler secret put GEMINI_API_KEY`.
6. For one-time local checks, pass the value only inside the visible terminal process, usually as an environment variable to the child command via `run-with-secret.sh`.

## Workflow

1. Identify the secret by name and purpose, not value.
2. Build a command that contains only the secret name, purpose, and destination.
3. Open the command in a visible terminal:

```bash
"$SKILL_DIR/scripts/open-secret-terminal.sh" --wait --cwd "$PWD" -- \
  pnpm wrangler secret put GEMINI_API_KEY
```

4. Tell the user to paste/type the value into that terminal prompt.
5. Verify with a non-secret command when available.

Resolve `SKILL_DIR` from the loaded `SKILL.md` path. Do not hard-code an installation path.

`--wait` blocks until the command in the terminal finishes and returns its exit
code. It gives up after 10 minutes by default (`--timeout <seconds>` to change);
exit code 124 means the user never completed the entry.

## One-Time Terminal Handoff

Use this when the assistant needs a secret for one local command and there is no
native CLI prompt to use. The value is entered in Terminal, not chat, and is made
available only to the child process as the environment variable named by `--env`.

Input is visible by default so the user can tell whether paste worked. Add
`--hidden` only when the user wants masked input.

```bash
"$SKILL_DIR/scripts/open-secret-terminal.sh" --wait --cwd "$PWD" -- \
  "$SKILL_DIR/scripts/run-with-secret.sh" \
  --env CLIENT_SUPABASE_SERVICE_ROLE_KEY \
  --prompt "CLIENT_SUPABASE_SERVICE_ROLE_KEY" \
  --purpose "Check Supabase school counts" \
  -- node scripts/check-supabase-counts.mjs
```

The target command must read the value from the named environment variable. It
must not print the value. Return only non-secret output or write non-secret
results to a file the assistant can read.

## Persistent Storage

Persistent storage is not the default recommendation. If the user wants reuse, suggest a normal user-controlled store and run that store's own interactive flow in the visible terminal. Common options include macOS Keychain, 1Password, Bitwarden, KeePassXC, OS keyrings, or the platform's managed secret store.

Do not improvise commands that print a stored value or pass it as an argument.

## Fallback

If Terminal.app cannot be controlled, give the exact non-secret command for the
user to run manually and remind them to enter the value in Terminal, not in chat.

## Boundary

This prevents accidental disclosure into chat, model context, shell arguments,
normal tool output, and files created by this skill. It is not isolation from a
malicious local process, shell startup hooks, clipboard history, screen
recording, process environment inspection by a local adversary, or an untrusted
target CLI. It also cannot stop a compromised or prompt-injected assistant from
choosing a malicious destination — the `[Secret Manager] Destination:` and
one-time input banners in Terminal are the user's chance to catch that. Read
them before typing.
