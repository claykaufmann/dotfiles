#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SUBJECT="${SCRIPT_DIR}/tmux-agent-status.sh"
readonly TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/claude-tmux-agent-status.XXXXXX")"
readonly TEST_HOME="${TMP_DIR}/home"
readonly CALLS_FILE="${TMP_DIR}/calls"
readonly STDOUT_FILE="${TMP_DIR}/stdout"
readonly STDERR_FILE="${TMP_DIR}/stderr"
readonly REAL_HELPER="${SCRIPT_DIR}/../../../tmux/.config/tmux/scripts/tmux-agent-status"
readonly REAL_TMUX="$(command -v tmux)"
readonly TMUX_SOCKET="claude-status-$$"
readonly TMUX_BIN="${TMP_DIR}/bin"

passed=0

cleanup() {
  "$REAL_TMUX" -L "$TMUX_SOCKET" kill-server >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_action() {
  local label="$1"
  local action="$2"
  local payload="$3"
  local expected="$4"
  local fail_helper="${5:-0}"
  local actual

  : >"$CALLS_FILE"
  : >"$STDOUT_FILE"
  : >"$STDERR_FILE"
  if ! printf '%s' "$payload" | env HOME="$TEST_HOME" CALLS_FILE="$CALLS_FILE" FAIL_HELPER="$fail_helper" bash "$SUBJECT" "$action" >"$STDOUT_FILE" 2>"$STDERR_FILE"; then
    fail "$label (hook exited nonzero)"
  fi
  [[ ! -s "$STDOUT_FILE" ]] || fail "$label (hook wrote stdout)"
  [[ ! -s "$STDERR_FILE" ]] || fail "$label (hook wrote stderr)"
  actual="$(cat "$CALLS_FILE")"
  [[ "$actual" == "$expected" ]] || fail "$label (expected: <$expected>, actual: <$actual>)"

  passed=$((passed + 1))
  printf 'ok %d - %s\n' "$passed" "$label"
}

mkdir -p "$TEST_HOME/.config/tmux/scripts"
cat >"$TEST_HOME/.config/tmux/scripts/tmux-agent-status" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CALLS_FILE:?}"
if [[ "${FAIL_HELPER:-0}" == "1" ]]; then
  printf 'unexpected helper stdout\n'
  printf 'unexpected helper stderr\n' >&2
  exit 7
fi
EOF

assert_action "clear maps to helper clear" clear '{}' 'clear'
assert_action "needs-action maps to the shared state" needs-action '{}' 'set needs-action'
assert_action "failure maps to the shared state" failed '{}' 'set failed'
assert_action "explicit done maps to the shared state" done '{}' 'set done'
assert_action "idle Stop marks done" stop '{"background_tasks":[],"session_crons":[]}' 'set done'
assert_action "missing Stop arrays preserve current state" stop '{}' ''
assert_action "background tasks suppress completion without clearing" stop '{"background_tasks":[{"id":"bg-1"}],"session_crons":[]}' ''
assert_action "session crons suppress completion without clearing" stop '{"background_tasks":[],"session_crons":[{"id":"cron-1"}]}' ''
assert_action "malformed Stop input preserves current state" stop 'not-json' ''
assert_action "unknown actions are silent no-ops" unknown '{}' ''
assert_action "present helper failures are silent and non-blocking" done '{}' 'set done' 1

mv "$TEST_HOME/.config/tmux/scripts/tmux-agent-status" "$TEST_HOME/.config/tmux/scripts/tmux-agent-status.off"
assert_action "missing helper is a silent no-op" done '{}' ''

mkdir -p "$TMUX_BIN"
cat >"$TMUX_BIN/tmux" <<EOF
#!/usr/bin/env bash
exec "$REAL_TMUX" -L "$TMUX_SOCKET" -f /dev/null "\$@"
EOF
chmod +x "$TMUX_BIN/tmux"
"$REAL_TMUX" -L "$TMUX_SOCKET" -f /dev/null new-session -d -s claude-status
pane="$("$REAL_TMUX" -L "$TMUX_SOCKET" display-message -p '#{pane_id}')"
window="$("$REAL_TMUX" -L "$TMUX_SOCKET" display-message -p '#{window_id}')"
cp "$REAL_HELPER" "$TEST_HOME/.config/tmux/scripts/tmux-agent-status"

: >"$STDOUT_FILE"
: >"$STDERR_FILE"
printf '%s' '{"background_tasks":[],"session_crons":[]}' |
  HOME="$TEST_HOME" PATH="$TMUX_BIN:$PATH" TMUX=isolated-test-server TMUX_PANE="$pane" \
  bash "$SUBJECT" stop >"$STDOUT_FILE" 2>"$STDERR_FILE"
[[ ! -s "$STDOUT_FILE" && ! -s "$STDERR_FILE" ]] || fail "real tmux lifecycle (hook emitted output)"
[[ "$("$REAL_TMUX" -L "$TMUX_SOCKET" show-options -p -q -v -t "$pane" @ck_agent_status)" == "done" ]] || fail "real tmux lifecycle (idle Stop did not set done)"
[[ "$(HOME="$TEST_HOME" PATH="$TMUX_BIN:$PATH" TMUX=isolated-test-server TMUX_PANE="$pane" bash "$REAL_HELPER" render-window "$window")" == ' #[fg=#a6d189]󰄬#[fg=#c6d0f5]' ]] || fail "real tmux lifecycle (done marker mismatch)"

printf '{}' |
  HOME="$TEST_HOME" PATH="$TMUX_BIN:$PATH" TMUX=isolated-test-server TMUX_PANE="$pane" \
  bash "$SUBJECT" needs-action >"$STDOUT_FILE" 2>"$STDERR_FILE"
[[ "$("$REAL_TMUX" -L "$TMUX_SOCKET" show-options -p -q -v -t "$pane" @ck_agent_status)" == "needs-action" ]] || fail "real tmux lifecycle (needs-action state mismatch)"
[[ "$(HOME="$TEST_HOME" PATH="$TMUX_BIN:$PATH" TMUX=isolated-test-server TMUX_PANE="$pane" bash "$REAL_HELPER" render-window "$window")" == ' #[fg=#e5c890]󰋗#[fg=#c6d0f5]' ]] || fail "real tmux lifecycle (action marker mismatch)"

printf '%s' '{"background_tasks":[{"id":"bg-1"}],"session_crons":[]}' |
  HOME="$TEST_HOME" PATH="$TMUX_BIN:$PATH" TMUX=isolated-test-server TMUX_PANE="$pane" \
  bash "$SUBJECT" stop >"$STDOUT_FILE" 2>"$STDERR_FILE"
[[ "$("$REAL_TMUX" -L "$TMUX_SOCKET" show-options -p -q -v -t "$pane" @ck_agent_status)" == "needs-action" ]] || fail "real tmux lifecycle (non-idle Stop erased action state)"

printf '{}' |
  HOME="$TEST_HOME" PATH="$TMUX_BIN:$PATH" TMUX=isolated-test-server TMUX_PANE="$pane" \
  bash "$SUBJECT" clear >"$STDOUT_FILE" 2>"$STDERR_FILE"
[[ -z "$("$REAL_TMUX" -L "$TMUX_SOCKET" show-options -p -q -v -t "$pane" @ck_agent_status)" ]] || fail "real tmux lifecycle (clear left pane state)"
passed=$((passed + 1))
printf 'ok %d - real helper lifecycle uses an isolated tmux server\n' "$passed"

printf '1..%d\n' "$passed"
