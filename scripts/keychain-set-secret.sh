#!/bin/bash
set -euo pipefail
set +x

usage() {
  cat >&2 <<'USAGE'
Usage: keychain-set-secret.sh --service NAME [--account NAME] [--label TEXT] [--comment TEXT]
USAGE
}

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

service=""
account="${USER:-user}"
label=""
comment=""

if [[ "${SECRET_MANAGER_COLOR:-}" == "1" || ( -t 1 && -z "${NO_COLOR:-}" ) ]]; then
  orange=$'\033[38;5;173m'
  bold=$'\033[1m'
  reset=$'\033[0m'
else
  orange=""
  bold=""
  reset=""
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      service="$2"
      shift 2
      ;;
    --account)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      account="$2"
      shift 2
      ;;
    --label)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      label="$2"
      shift 2
      ;;
    --comment)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      comment="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

[[ -n "$service" ]] || die "--service is required."
[[ -n "$label" ]] || label="$service"
[[ -t 0 && -t 1 ]] || die "A visible interactive terminal is required."

printf '\n%s%sKeychainに保存します%s\n' "$orange" "$bold" "$reset"
printf '  Service : %s\n' "$service"
printf '  Account : %s\n' "$account"
printf '  Label   : %s\n' "$label"
[[ -n "$comment" ]] && printf '  Comment : %s\n' "$comment"
printf '\n'

secret=""
cleanup() {
  unset secret 2>/dev/null || true
}
trap cleanup EXIT

IFS= read -r -p "${orange}${bold}input here:${reset} " secret || die "Input cancelled."
[[ -n "$secret" ]] || die "No value entered."

command=(security add-generic-password -a "$account" -s "$service" -l "$label")
if [[ -n "$comment" ]]; then
  command+=(-j "$comment")
fi
command+=(-U -w "$secret")
"${command[@]}" >/dev/null

unset secret
printf 'Saved: %s\n' "$service"
