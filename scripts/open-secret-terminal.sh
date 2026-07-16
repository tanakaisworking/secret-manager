#!/bin/bash
set -euo pipefail
umask 077

usage() {
  cat >&2 <<'USAGE'
Usage: open-secret-terminal.sh [--wait] [--timeout <seconds>] [--cwd <directory>]
  [--key-type TEXT] [--storage TEXT] [--ttl SECONDS] [--secret-name NAME] [--purpose TEXT]
  -- <command> [args...]
USAGE
}

[[ "$(/usr/bin/uname -s)" == "Darwin" ]] || {
  printf 'Secret Manager requires local macOS.\n' >&2
  exit 1
}
[[ -x /usr/bin/osascript ]] || {
  printf 'osascript was not found at /usr/bin/osascript.\n' >&2
  exit 1
}

cwd="$PWD"
wait_for_completion=0
timeout_seconds=600
key_type="一時的"
storage="なし（プロセスのメモリのみ）"
session_ttl=""
secret_name="（コマンド内で使用）"
purpose="指定された処理のために一時利用"

# This script always opens a visible Terminal; color is enabled for that UI by default.
# Set SECRET_MANAGER_COLOR=0 when a plain-text handoff is required.
if [[ "${SECRET_MANAGER_COLOR:-1}" != "0" ]]; then
  header_command='orange=$(tput setaf 173); bold=$(tput bold); reset=$(tput sgr0); printf "%s%s**************************************************%s\n%s%s  Secret Manager%s\n%s%s**************************************************%s\n" "$orange" "$bold" "$reset" "$orange" "$bold" "$reset" "$orange" "$bold" "$reset"'
else
  header_command='printf "%s\n" "**************************************************" "  Secret Manager" "**************************************************"'
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      wait_for_completion=1
      shift
      ;;
    --timeout)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      timeout_seconds="$2"
      shift 2
      ;;
    --cwd)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      cwd="$2"
      shift 2
      ;;
    --key-type)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      key_type="$2"
      shift 2
      ;;
    --storage)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      storage="$2"
      shift 2
      ;;
    --ttl)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      session_ttl="$2"
      shift 2
      ;;
    --secret-name)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      secret_name="$2"
      shift 2
      ;;
    --purpose)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      purpose="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

[[ $# -gt 0 ]] || { usage; exit 2; }
[[ -d "$cwd" ]] || {
  printf 'Directory not found: %s\n' "$cwd" >&2
  exit 1
}
case "$timeout_seconds" in
  ''|*[!0-9]*)
    printf -- '--timeout requires a positive integer of seconds.\n' >&2
    exit 2
    ;;
esac

# Single-quote a value for a POSIX-style shell without evaluating it.
shell_quote() {
  local value="$1"
  value=${value//\'/\'\\\'\'}
  printf "'%s'" "$value"
}

# One readable line the user can verify before typing a value.
# %q escapes control characters, so the banner cannot be spoofed by argument content.
display_command=""
for arg in "$@"; do
  display_command+="${display_command:+ }$(printf '%q' "$arg")"
done
if [[ -n "$session_ttl" ]]; then
  case "$session_ttl" in
    ''|*[!0-9]*)
      printf -- '--ttl requires a positive integer of seconds.\n' >&2
      exit 2
      ;;
  esac
  if (( session_ttl % 3600 == 0 )); then
    expiry="$((session_ttl / 3600))時間後に自動失効"
  elif (( session_ttl % 60 == 0 )); then
    expiry="$((session_ttl / 60))分後に自動失効"
  else
    expiry="${session_ttl}秒後に自動失効"
  fi
else
  expiry="コマンド終了時に破棄"
fi
panel=""
panel+="  Key Type : $key_type"$'\n'
panel+="  保存先   : $storage"$'\n'
panel+="  有効期限 : $expiry"$'\n'
panel+="  Secret   : $secret_name"$'\n'
panel+="  用途     : $purpose"$'\n'
panel+=$'\n  実行先（確認用）:\n'
panel+="    $display_command"$'\n'
panel+="    (in $(printf '%q' "$cwd"))"$'\n'
panel+=$'\n  上記を確認してから、Terminal内の input here: 欄に入力してください。\n\n'

panel_command="printf '%s\\n'"
while IFS= read -r panel_line; do
  panel_command+=" $(shell_quote "$panel_line")"
done <<< "$panel"
inner_command="$header_command; $panel_command && export SECRET_MANAGER_UI_SHOWN=1 SECRET_MANAGER_COLOR=1 && cd $(shell_quote "$cwd") &&"
for arg in "$@"; do
  inner_command+=" $(shell_quote "$arg")"
done

status_dir=""
status_file=""
cleanup() {
  if [[ -n "$status_dir" && -d "$status_dir" ]]; then
    rm -rf -- "$status_dir"
  fi
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

if [[ $wait_for_completion -eq 1 ]]; then
  status_dir="$(mktemp -d "${TMPDIR:-/tmp}/secret-manager.XXXXXX")"
  chmod 700 "$status_dir"
  status_file="$status_dir/status"

  # The status file contains only an exit code. No secret is placed in this command.
  inner_command="set +e; $inner_command; sm_rc=\$?; printf '%s\\n' \"\$sm_rc\" > $(shell_quote "$status_file"); printf '\\n[Secret Manager] finished (exit %s)\\n' \"\$sm_rc\"; exit \"\$sm_rc\""
fi

# Force a known shell for the generated command and suppress BASH_ENV/ENV startup hooks.
terminal_command="/usr/bin/env BASH_ENV=/dev/null ENV=/dev/null /bin/bash --noprofile --norc -c $(shell_quote "$inner_command")"

/usr/bin/osascript - "$terminal_command" >/dev/null <<'APPLESCRIPT'
on run argv
  tell application "Terminal"
    activate
    do script item 1 of argv
  end tell
end run
APPLESCRIPT

if [[ $wait_for_completion -eq 0 ]]; then
  exit 0
fi

deadline=$(( SECONDS + timeout_seconds ))
while [[ ! -f "$status_file" ]]; do
  if (( SECONDS >= deadline )); then
    printf '[Secret Manager] Timed out after %ss waiting for the terminal to finish.\n' "$timeout_seconds" >&2
    exit 124
  fi
  sleep 0.2
done

IFS= read -r result < "$status_file" || result=1
case "$result" in
  ''|*[!0-9]*) result=1 ;;
esac
if (( result < 0 || result > 255 )); then
  result=1
fi
exit "$result"
