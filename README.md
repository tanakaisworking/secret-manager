# Secret Manager

Secret Manager is a small workflow for AI coding assistants to use secrets by
name without seeing secret values.

The assistant may know:

- the secret name
- the target command
- the project path

The assistant must not know the secret value. Instead, it opens a visible local terminal so the human can verify the destination and type or paste the value outside chat.

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

## Example

```text
Set GEMINI_API_KEY for this Cloudflare Worker.
```

The assistant should run a command like:

```bash
scripts/open-secret-terminal.sh --wait --cwd "$PWD" -- \
  pnpm wrangler secret put GEMINI_API_KEY
```

The user enters the actual value only in the terminal prompt.

## The Protocol

1. The user gives the assistant only the secret name and destination.
2. The assistant builds a command that contains no secret value.
3. The assistant opens a visible local terminal, or tells the user the exact command to run.
4. The user verifies the destination and enters the secret value outside chat.
5. The assistant verifies success using a non-secret command if one exists.

## Files

- `SKILL.md` - skill instructions for local coding assistants
- `scripts/open-secret-terminal.sh` - opens Terminal.app with a non-secret command
- `scripts/one-time-pipe.sh` - hidden one-line stdin handoff for CLIs that explicitly read from stdin
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

Keep the `scripts/` directory in the repository, or copy it somewhere stable, so Cursor can reference `open-secret-terminal.sh` and `one-time-pipe.sh`.

## Security Boundary

This prevents accidental disclosure into chat, model context, shell arguments, normal tool output, and files created by this skill.

It is not isolation from a malicious local process, shell startup hooks, clipboard history, screen recording, or an untrusted target CLI.

## License

MIT
