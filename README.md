# Secret Manager

Secret Manager is a small workflow for AI coding assistants to use secrets by
name without seeing secret values.

The assistant may know:

- the secret name
- the target command
- the project path

The assistant must not know the secret value. Instead, it opens a visible local
terminal so the human can verify the destination and type or paste the value
outside chat.

## When To Use

Use this whenever the assistant needs a real value that should not be pasted
into chat, including API keys, access tokens, PATs, service role keys, JWTs,
OAuth client secrets, webhook signing secrets, passwords, database URLs with
credentials, SSH/private keys, recovery codes, one-time credentials, or
vendor/client credentials.

It should also trigger on natural phrasing like "secret", "API key", "token",
"password", "シークレット", "鍵", "認証情報", "これ使って", "渡すよ", or "ログイン情報"
when the value grants account or service access.

Do not use it for public project IDs, public URLs, environment variable names
without values, or general security discussion where no secret value is needed.

## Example: Native CLI Prompt

```text
Set GEMINI_API_KEY for this Cloudflare Worker.
```

The assistant should run a command like:

```bash
scripts/open-secret-terminal.sh --wait --cwd "$PWD" \
  --key-type "一時的（コマンド終了時に破棄）" \
  --storage "なし（プロセスのメモリのみ）" \
  --secret-name GEMINI_API_KEY \
  --purpose "Cloudflare Workerへ登録" -- \
  scripts/run-with-secret.sh \
  --env GEMINI_API_KEY \
  --prompt "GEMINI_API_KEY" \
  --purpose "Cloudflare Workerへ登録" -- \
  /bin/sh -lc 'printf "%s\n" "$GEMINI_API_KEY" | pnpm wrangler secret put GEMINI_API_KEY'
```

The user enters the actual value only in the visible terminal prompt.

The Secret Manager header and `input here:` prompt use orange terminal emphasis. Set
`SECRET_MANAGER_COLOR=0` when a plain-text handoff is preferred.

## Example: Session Handoff

For several commands that need the same secret, keep it only in a dedicated
process for a bounded session:

```bash
scripts/secret-session start --name supabase --env SUPABASE_ACCESS_TOKEN --ttl 3600
scripts/secret-session exec --name supabase -- supabase db query ...
scripts/secret-session exec --name supabase -- supabase db query ...
scripts/secret-session clear --name supabase
```

When `start` is called from a non-interactive shell, it opens Terminal.app for
the one-time input and returns after the session is ready. The secret is held
only in that process's memory. A temporary Unix socket is used for control, but
it contains no secret; TTL expiry or `clear` removes the session metadata.

## Example: One-Time Local Handoff

```text
Use this service role key once to check Supabase school counts.
```

The assistant should run a command like:

```bash
scripts/open-secret-terminal.sh --wait --cwd "$PWD" \
  --key-type "一時的（コマンド終了時に破棄）" \
  --storage "なし（プロセスのメモリのみ）" \
  --secret-name CLIENT_SUPABASE_SERVICE_ROLE_KEY \
  --purpose "Check Supabase school counts" -- \
  scripts/run-with-secret.sh \
  --env CLIENT_SUPABASE_SERVICE_ROLE_KEY \
  --prompt "CLIENT_SUPABASE_SERVICE_ROLE_KEY" \
  --purpose "Check Supabase school counts" \
  -- node scripts/check-supabase-counts.mjs
```

`run-with-secret.sh` asks for the value in Terminal and exposes it to the child
command as the named environment variable. Input is always visible so the user
can see whether paste worked. The handoff screen shows the key type, storage location, expiry,
secret name, purpose, and destination command before the `input here:` prompt. The
panel uses orange terminal emphasis; set `SECRET_MANAGER_COLOR=0` for plain text.

## Example: Keychain Persistence

```bash
scripts/open-secret-terminal.sh --wait --cwd "$PWD" \
  --key-type "永続（Keychain）" \
  --storage "macOS Keychain" \
  --secret-name SUPABASE_ACCESS_TOKEN_HELLOINTER \
  --purpose "Hello International School Supabase操作用に保存" -- \
  scripts/keychain-set-secret.sh \
  --service SUPABASE_ACCESS_TOKEN_HELLOINTER \
  --account hello-international-school \
  --comment "Hello International School Supabase access token"
```

Read it later without printing it:

```bash
SUPABASE_ACCESS_TOKEN="$(security find-generic-password -s SUPABASE_ACCESS_TOKEN_HELLOINTER -w)" your-command
```

## The Protocol

1. The user gives the assistant only the secret name and destination.
2. The assistant builds a command that contains no secret value.
3. The assistant opens a visible local terminal, or tells the user the exact command to run.
4. The user verifies the destination and enters the secret value outside chat.
5. The assistant verifies success using a non-secret command if one exists.

## Files

- `SKILL.md` - skill instructions for local coding assistants
- `scripts/open-secret-terminal.sh` - opens Terminal.app with the Secret Manager handoff panel
- `scripts/run-with-secret.sh` - one-time Terminal input vessel for a child command
- `scripts/keychain-set-secret.sh` - visible-input helper for macOS Keychain persistence
- `scripts/secret-session` - bounded memory-only session for repeated commands
- `agents/openai.yaml` - optional OpenAI/Codex metadata

## Compatibility

The workflow is assistant-agnostic and can be followed by Claude Code, Codex, Cursor, or similar local AI coding assistants.

The bundled scripts target local macOS with Terminal.app and `osascript`.

## Install

Use `SKILL.md` as the source instructions for your assistant.

The examples below assume you are in the directory that contains the cloned `secret-manager/` folder.

### Codex

Copy the skill folder into Codex's skills directory:

```bash
cp -R secret-manager ~/.codex/skills/
```

### Claude Code

Copy the skill folder into Claude's skills directory:

```bash
cp -R secret-manager ~/.claude/skills/
```

### Cursor

Cursor does not use this exact skill folder format. Add the rules from `SKILL.md` to a project rule instead:

```bash
mkdir -p .cursor/rules
cp secret-manager/SKILL.md .cursor/rules/secret-manager.mdc
```

Keep the `scripts/` directory in the repository, or copy it somewhere stable, so Cursor can reference `open-secret-terminal.sh` and `run-with-secret.sh`.

## Security Boundary

This prevents accidental disclosure into chat, model context, shell arguments,
normal tool output, and files created by this skill.

It is not isolation from a malicious local process, shell startup hooks,
clipboard history, screen recording, process environment inspection by a local
adversary, or an untrusted target CLI. It also cannot stop a compromised or
prompt-injected assistant from choosing a malicious destination — the Terminal
destination banner is the user's chance to catch that. Read it before typing.

## License

MIT
