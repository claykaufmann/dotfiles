#!/usr/bin/env bash
set -euo pipefail

readonly action="${1:-}"
readonly helper="${HOME:-}/.config/tmux/scripts/tmux-agent-status"
readonly input="$(cat 2>/dev/null || true)"

run_helper() {
  [[ -n "${HOME:-}" && -f "$helper" ]] || return 0
  bash "$helper" "$@" >/dev/null 2>&1 || true
}

case "$action" in
  clear)
    run_helper clear
    ;;
  needs-action|done|failed)
    run_helper set "$action"
    ;;
  stop)
    if command -v jq >/dev/null 2>&1 && jq -e '
      ((.background_tasks | type) == "array") and
      ((.background_tasks | length) == 0) and
      ((.session_crons | type) == "array") and
      ((.session_crons | length) == 0)
    ' <<<"$input" >/dev/null 2>&1; then
      run_helper set done
    else
      # Non-idle or malformed Stop input is not authoritative: preserve any
      # needs-action state owned by continuing background work.
      :
    fi
    ;;
  *)
    # Unknown actions are ignored so hook misconfiguration cannot block Claude.
    ;;
esac

exit 0
