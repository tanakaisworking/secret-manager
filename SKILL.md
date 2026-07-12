---
name: secret-manager
description: Use when an AI coding assistant such as Claude Code, Codex, Cursor, or another local assistant needs a real API key, token, password, シークレット, or single-line credential to complete a local CLI task, deployment, login, environment setup, or rotation. The user should tell the assistant only the secret name and destination, never the value. Open a visible local terminal so the user can verify the exact command and enter the value outside chat. Do not use for general security discussion, secret scanning, or code that only mentions environment variable names.
metadata:
  version: "0.5.0"
  compatibility: Local macOS with Terminal.app and osascript for bundled scripts; the workflow is assistant-agnostic and can be followed by Claude Code, Codex, Cursor, or similar local coding assistants.
---

# Secret Manager

The core contract: the assistant may know the secret name, destination command, and project path; the assistant must not know the secret value.

Use the smallest safe path. If the target CLI already prompts securely, just open that prompt in a visible terminal. Store secrets only when the user explicitly wants reuse.

## Rules

1. Never ask the user to paste a secret value into chat.
2. Never put a secret value in command arguments, environment variables, heredocs, temp files, logs, or agent-visible output.
3. The assistant may handle non-secret metadata: secret name, service name, account name, working directory, and target command.
4. Show the user the destination command before value entry.
5. Prefer platform CLIs that accept a secret name and prompt for the value, such as `wrangler secret put GEMINI_API_KEY`.

## Workflow

1. Identify the secret by name, not value.
2. Build a command that contains only the secret name and destination.
3. Open the command in a visible terminal:

```bash
"$SKILL_DIR/scripts/open-secret-terminal.sh" --wait --cwd "$PWD" -- \
  pnpm wrangler secret put GEMINI_API_KEY
```

4. Tell the user to paste/type the value into that terminal prompt.
5. Verify with a non-secret command when available.

Resolve `SKILL_DIR` from the loaded `SKILL.md` path. Do not hard-code an installation path.

## One-Time Stdin Handoff

Use this only when the target command is explicitly designed to read one secret line from stdin:

```bash
"$SKILL_DIR/scripts/open-secret-terminal.sh" --wait --cwd "$PWD" -- \
  "$SKILL_DIR/scripts/one-time-pipe.sh" \
  --prompt "GEMINI_API_KEY" -- \
  target-cli secret import GEMINI_API_KEY
```

The wrapper displays the resolved destination command before accepting hidden input.

## Persistent Storage

Persistent storage is not the default recommendation. If the user wants reuse, suggest a normal user-controlled store and run that store's own interactive flow in the visible terminal. Common options include macOS Keychain, 1Password, Bitwarden, KeePassXC, OS keyrings, or the platform's managed secret store.

Do not improvise commands that print a stored value or pass it as an argument. If unsure, fall back to one-time handoff.

## Fallback

If Terminal.app cannot be controlled, give the exact non-secret command for the user to run manually and remind them to enter the value in the CLI prompt, not in chat.

## Boundary

This prevents accidental disclosure into chat, model context, shell arguments, normal tool output, and files created by this skill. It is not isolation from a malicious local process, shell startup hooks, clipboard history, screen recording, or an untrusted target CLI.
