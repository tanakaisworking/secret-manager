#!/bin/bash
set -euo pipefail
umask 077

usage() {
  cat >&2 <<'USAGE'
Usage: open-secret-terminal.sh [--wait] [--cwd <directory>] -- <command> [args...]
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      wait_for_completion=1
      shift
      ;;
    --cwd)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      cwd="$2"
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

# Single-quote a value for a POSIX-style shell without evaluating it.
shell_quote() {
  local value="$1"
  value=${value//\'/\'\\\'\'}
  printf "'%s'" "$value"
}

inner_command="cd $(shell_quote "$cwd") &&"
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

/usr/bin/osascript - "$terminal_command" <<'APPLESCRIPT'
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

while [[ ! -f "$status_file" ]]; do
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
