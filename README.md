# Secret Manager

Secret Manager is a small agent workflow for using secrets by name without exposing secret values to the AI.

The agent may know:

- the secret name
- the target command
- the project path

The agent must not know the secret value. Instead, it opens a visible local terminal so the human can verify the destination and type or paste the value outside chat.

## Use Case

```text
Set GEMINI_API_KEY for this Cloudflare Worker.
```

The agent should run a command like:

```bash
scripts/open-secret-terminal.sh --wait --cwd "$PWD" -- \
  pnpm wrangler secret put GEMINI_API_KEY
```

The user enters the actual value only in the terminal prompt.

## Files

- `SKILL.md` - skill instructions for local coding agents
- `scripts/open-secret-terminal.sh` - opens Terminal.app with a non-secret command
- `scripts/one-time-pipe.sh` - hidden one-line stdin handoff for CLIs that explicitly read from stdin
- `agents/openai.yaml` - Codex/OpenAI skill metadata

## Compatibility

The workflow is agent-agnostic and can be followed by Claude Code, Codex, Cursor, or similar local coding agents.

The bundled scripts target local macOS with Terminal.app and `osascript`.

## Install

Copy this directory into your agent's skills directory. For Codex:

```bash
cp -R secret-manager ~/.codex/skills/
```

## Security Boundary

This prevents accidental disclosure into chat, model context, shell arguments, normal tool output, and files created by this skill.

It is not isolation from a malicious local process, shell startup hooks, clipboard history, screen recording, or an untrusted target CLI.

## License

MIT
