# Secret Manager

Secret Manager is a small workflow for AI coding assistants to use secrets by name without seeing secret values.

It is not tied to Codex. The same protocol works for Claude Code, Codex, Cursor, and other local assistants that can open a terminal or tell a human what command to run.

The assistant may know:

- the secret name
- the target command
- the project path

The assistant must not know the secret value. Instead, it opens a visible local terminal so the human can verify the destination and type or paste the value outside chat.

## Use Case

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

## Install Or Adapt

Use `SKILL.md` as the source instructions for your assistant.

For tools with a skills directory, copy the folder there. For Codex:

```bash
cp -R secret-manager ~/.codex/skills/
```

For tools without this skill format, adapt the rules from `SKILL.md` into the tool's project rules, custom instructions, or memory.

## Security Boundary

This prevents accidental disclosure into chat, model context, shell arguments, normal tool output, and files created by this skill.

It is not isolation from a malicious local process, shell startup hooks, clipboard history, screen recording, or an untrusted target CLI.

## License

MIT
