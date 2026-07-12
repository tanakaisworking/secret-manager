#!/bin/bash
set -euo pipefail
set +x
unset BASH_XTRACEFD 2>/dev/null || true

usage() {
  cat >&2 <<'USAGE'
Usage: one-time-pipe.sh [--prompt <label>] -- <command> [args...]
USAGE
}

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

validate_display_text() {
  local field="$1" value="$2" max="$3"
  [[ -n "$value" && ${#value} -le $max ]] || die "$field is empty or too long."
  case "$value" in
    *$'\n'*|*$'\r'*|*$'\e'*|*$'\a'*) die "$field contains terminal control characters." ;;
  esac
}

resolve_target() {
  local command_name="$1" resolved
  if [[ "$command_name" == */* ]]; then
    [[ -x "$command_name" ]] || die "Target is not executable: $command_name"
    resolved="$command_name"
  else
    resolved="$(type -P "$command_name" 2>/dev/null || true)"
    [[ -n "$resolved" ]] || die "Target command not found: $command_name"
  fi
  printf '%s\n' "$resolved"
}

print_command() {
  local arg
  printf '  '
  for arg in "$@"; do
    printf '%q ' "$arg"
  done
  printf '\n'
}

prompt="Secret"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      prompt="$2"
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
[[ -t 0 && -t 1 ]] || die "A visible interactive terminal is required. Run this through open-secret-terminal.sh."
validate_display_text "Prompt" "$prompt" 160

target=("$@")
resolved_target="$(resolve_target "${target[0]}")"
target=("$resolved_target" "${target[@]:1}")

secret=""
tty_state="$(stty -g 2>/dev/null || true)"
cleanup() {
  unset secret 2>/dev/null || true
  if [[ -n "$tty_state" ]]; then
    stty "$tty_state" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

printf '\nSecret Manager — one-time handoff\n'
printf 'Destination:\n'
print_command "${target[@]}"
printf '\nThe value is not stored by this skill. Paste only if the destination above is correct.\n\n'
IFS= builtin read -r -s -p "$prompt: " secret || {
  printf '\nInput cancelled.\n' >&2
  exit 1
}
printf '\n'
[[ -n "$secret" ]] || die "No value entered."

set +e
builtin printf '%s' "$secret" | "${target[@]}"
result=${PIPESTATUS[1]}
set -e
unset secret
exit "$result"
