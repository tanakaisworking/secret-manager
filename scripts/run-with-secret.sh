#!/bin/bash
set -euo pipefail
set +x
unset BASH_XTRACEFD 2>/dev/null || true

usage() {
  cat >&2 <<'USAGE'
Usage: run-with-secret.sh --env NAME [--prompt LABEL] [--purpose TEXT] [--hidden] -- <command> [args...]
USAGE
}

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

env_name=""
prompt="value"
purpose=""
hidden=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      env_name="$2"
      shift 2
      ;;
    --prompt)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      prompt="$2"
      shift 2
      ;;
    --purpose)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      purpose="$2"
      shift 2
      ;;
    --hidden)
      hidden=1
      shift
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
[[ "$env_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "--env must be a valid environment variable name."
[[ -t 0 && -t 1 ]] || die "A visible interactive terminal is required. Run this through open-secret-terminal.sh."

print_command() {
  local arg
  printf '  '
  for arg in "$@"; do
    printf '%q ' "$arg"
  done
  printf '\n'
}

render_panel() {
  printf '\n**************************************************\n'
  printf '  Secret Manager\n'
  printf '**************************************************\n'
  printf '  Key Type : 一時的（コマンド終了時に破棄）\n'
  printf '  保存先   : なし（プロセスのメモリのみ）\n'
  printf '  有効期限 : コマンド終了時\n'
  printf '  Secret   : %s\n' "$env_name"
  if [[ -n "$purpose" ]]; then
    printf '  用途     : %s\n' "$purpose"
  fi
  printf '\n  実行先（確認用）:\n'
  print_command "$@"
  printf '\n  上記を確認してから、Terminal内の value 欄に入力してください。\n\n'
}

secret=""
tty_state="$(stty -g 2>/dev/null || true)"
cleanup() {
  unset secret "$env_name" 2>/dev/null || true
  if [[ -n "$tty_state" ]]; then
    stty "$tty_state" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

if [[ "${SECRET_MANAGER_UI_SHOWN:-}" != "1" ]]; then
  render_panel "$@"
fi

if [[ $hidden -eq 1 ]]; then
  IFS= read -r -s -p "$prompt: " secret || die "Input cancelled."
  printf '\n'
else
  IFS= read -r -p "$prompt: " secret || die "Input cancelled."
fi
[[ -n "$secret" ]] || die "No value entered."

export "$env_name=$secret"
unset secret
"$@"
