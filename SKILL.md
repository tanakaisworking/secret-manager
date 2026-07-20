---
name: secret-manager
description: Use whenever an AI coding assistant such as Claude Code, Codex, Cursor, or another local assistant needs any real value that should normally not be pasted into chat: API keys, access tokens, refresh tokens, PATs, service role keys, JWTs, OAuth client secrets, webhook signing secrets, passwords, database URLs with credentials, SSH/private keys, recovery codes, one-time credentials, vendor/client credentials, or any pasted-looking credential even when the prefix is unknown. Trigger on phrasing such as "secret", "API key", "token", "password", "シークレット", "鍵", "認証情報", "これ使って", "渡すよ", or "ログイン情報" when the value grants account or service access. For an explicitly disposable, test-only, low-privilege secret that the user will revoke immediately after use, the user may provide the value in chat for one operation; do not repeat or persist it. Otherwise, the user should tell the assistant only the secret name and destination, never the value. Open a visible local terminal so the user can verify the exact command and enter the value outside chat. Do not use for general security discussion, secret scanning, public IDs, environment variable names without values, or non-secret configuration.
metadata:
  version: "0.9.1"
  compatibility: Local macOS with Terminal.app and osascript for bundled scripts; the workflow is assistant-agnostic and can be followed by Claude Code, Codex, Cursor, or similar local coding assistants.
---

# Secret Manager

The core contract: by default the assistant may know the secret name, destination command, and project path; the assistant must not know the secret value. The disposable-test exception below is deliberately narrow.

## Current project reference

For the MeetingCatcher BFF secret workflow:

- Local repository: `/Users/kotatsu/AI-BASE/ai-dev/dev/reki-note-api`
- GitHub repository: `https://github.com/tanakaisworking/reki-note-api`

Use the smallest usable path. Open a visible terminal, let the user paste the
value into a normal visible `input here:` prompt, then pass it directly to the
destination command. Do not use masked password boxes; paste failures are worse
than the extra masking in this local workflow.

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

## Disposable test-secret exception

If the user explicitly states that a secret is test-only, disposable, low-privilege, and will be disabled or revoked immediately after the test, the user may paste it into chat for one operation. This is allowed only when all of those conditions are clear.

- Warn once that chat history may retain the value and do not repeat, quote, or copy it into files, notes, logs, shell history, or persistent secret storage.
- Use it only for the requested one-shot test; do not deploy it or substitute it for a production credential.
- After the test, remind the user to disable or revoke it and treat it as unusable afterward.
- If the scope, lifetime, or revocation plan is unclear, use the normal visible-terminal workflow instead.

## Rules

1. For normal, reusable, production, or unknown-scope secrets, never ask the user to paste the value into chat. The disposable test-secret exception above is the only exception.
2. Never echo or persist a secret value in files, logs, shell history, or agent-visible output. Under the exception, the value may already exist in chat by the user's explicit choice, but it must not be repeated or copied elsewhere.
3. The assistant may handle non-secret metadata: secret name, service name, account name, working directory, and target command.
4. Show the user the destination command before value entry.
5. Hidden or masked input is prohibited. Do not pass `--hidden`; do not use a native CLI prompt if it masks input.
6. For one-time local checks, use `run-with-secret.sh`. For macOS Keychain persistence, use `keychain-set-secret.sh`.

## Workflow

1. Identify the secret by name and purpose, not value.
2. Build a command that contains only the secret name, purpose, and destination.
3. Open the command in a visible terminal:

```bash
"$SKILL_DIR/scripts/open-secret-terminal.sh" --wait --cwd "$PWD" \
  --key-type "一時的（コマンド終了時に破棄）" \
  --storage "なし（プロセスのメモリのみ）" \
  --secret-name GEMINI_API_KEY \
  --purpose "Cloudflare Workerへ登録" -- \
  "$SKILL_DIR/scripts/run-with-secret.sh" \
  --env GEMINI_API_KEY \
  --prompt "GEMINI_API_KEY" \
  --purpose "Cloudflare Workerへ登録" -- \
  /bin/sh -lc 'printf "%s\n" "$GEMINI_API_KEY" | pnpm wrangler secret put GEMINI_API_KEY'
```

4. Tell the user to paste/type the value into the visible `input here:` prompt.
5. Verify with a non-secret command when available.

Resolve `SKILL_DIR` from the loaded `SKILL.md` path. Do not hard-code an installation path.

`--wait` blocks until the command in the terminal finishes and returns its exit
code. It gives up after 10 minutes by default (`--timeout <seconds>` to change);
exit code 124 means the user never completed the entry.

## One-Time Terminal Handoff

Use this when the assistant needs a secret for one local command and there is no
native CLI prompt to use. The value is entered in Terminal, not chat, and is made
available to the child process as the environment variable named by `--env`.

Input is always visible so the user can tell whether paste worked.

```bash
"$SKILL_DIR/scripts/open-secret-terminal.sh" --wait --cwd "$PWD" \
  --key-type "一時的（コマンド終了時に破棄）" \
  --storage "なし（プロセスのメモリのみ）" \
  --secret-name CLIENT_SUPABASE_SERVICE_ROLE_KEY \
  --purpose "Check Supabase school counts" -- \
  "$SKILL_DIR/scripts/run-with-secret.sh" \
  --env CLIENT_SUPABASE_SERVICE_ROLE_KEY \
  --prompt "CLIENT_SUPABASE_SERVICE_ROLE_KEY" \
  --purpose "Check Supabase school counts" \
  -- node scripts/check-supabase-counts.mjs
```

The target command must read the value from the named environment variable. It
must not print the value. Return only non-secret output or write non-secret
results to a file the assistant can read. The terminal UI shows the key type,
storage location, expiry, purpose, and destination command before input.
The panel and `input here:` prompt use orange terminal emphasis; set
`SECRET_MANAGER_COLOR=0` for plain text.

If a target CLI only accepts the secret on stdin, run a small local shell command
inside `run-with-secret.sh`, such as:

```bash
/bin/sh -lc 'printf "%s\n" "$SECRET_NAME" | target-cli secret put SECRET_NAME'
```

## Persistent Storage

Persistent storage is not the default recommendation. If the user wants reuse,
use the simplest user-controlled store. On macOS Keychain, use the bundled
visible-input helper:

```bash
"$SKILL_DIR/scripts/open-secret-terminal.sh" --wait --cwd "$PWD" \
  --key-type "永続（Keychain）" \
  --storage "macOS Keychain" \
  --secret-name SUPABASE_ACCESS_TOKEN_HELLOINTER \
  --purpose "Hello International School Supabase操作用に保存" -- \
  "$SKILL_DIR/scripts/keychain-set-secret.sh" \
  --service SUPABASE_ACCESS_TOKEN_HELLOINTER \
  --account hello-international-school \
  --comment "Hello International School Supabase access token"
```

Read later without printing it:

```bash
SUPABASE_ACCESS_TOKEN="$(security find-generic-password -s SUPABASE_ACCESS_TOKEN_HELLOINTER -w)" your-command
```

## Session Handoff

When several commands need the same secret in one short-lived work session, use
`scripts/secret-session` instead of asking for the value repeatedly:

```bash
scripts/secret-session start --name supabase --env SUPABASE_ACCESS_TOKEN --ttl 3600
scripts/secret-session exec --name supabase -- supabase db query ...
scripts/secret-session exec --name supabase -- supabase db query ...
scripts/secret-session clear --name supabase
```

`start` opens a visible Terminal automatically when called non-interactively
and returns only after the session has accepted the visible input.
The secret stays in the session process memory; the temporary Unix socket and
directory contain only session metadata. `clear` or TTL expiry removes them.
If the process is killed, the OS reclaims the secret memory; a stale metadata
directory may remain, but it contains no secret and can be ignored or removed.
Do not send the secret through arguments, files, logs, or assistant output.

## Fallback

If Terminal.app cannot be controlled, give the exact non-secret command for the
user to run manually and remind them to enter the value in Terminal, not in chat.

## Boundary

This prevents accidental disclosure into chat, model context, shell arguments,
normal tool output, and files created by this skill. It is not isolation from a
malicious local process, shell startup hooks, clipboard history, screen
recording, process environment inspection by a local adversary, or an untrusted
target CLI. It also cannot stop a compromised or prompt-injected assistant from
choosing a malicious destination — the Secret Manager panel and `input here:` prompt
in Terminal are the user's chance to catch that. Read the panel before typing.
