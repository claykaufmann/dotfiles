#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SUBJECT="${SCRIPT_DIR}/tmux-agent-status"
readonly REAL_TMUX="$(command -v tmux)"
readonly SOCKET="ck-agent-status-test-$$"
readonly TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tmux-agent-status.XXXXXX")"

passed=0

cleanup() {
  "$REAL_TMUX" -L "$SOCKET" kill-server >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

pass() {
  passed=$((passed + 1))
  printf 'ok %d - %s\n' "$passed" "$1"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  [[ "$actual" == "$expected" ]] || fail "$label (expected: <$expected>, actual: <$actual>)"
  pass "$label"
}

assert_fails() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$label (command unexpectedly succeeded)"
  fi
  pass "$label"
}

mkdir -p "$TMP_DIR/bin"
cat >"$TMP_DIR/bin/tmux" <<EOF
#!/usr/bin/env bash
exec "$REAL_TMUX" -L "$SOCKET" -f /dev/null "\$@"
EOF
chmod +x "$TMP_DIR/bin/tmux" "$SUBJECT"
export PATH="$TMP_DIR/bin:$PATH"

outside_output="$(env -u TMUX -u TMUX_PANE "$SUBJECT" set done)"
assert_eq "" "$outside_output" "set is a silent no-op outside tmux"
outside_render="$(env -u TMUX -u TMUX_PANE "$SUBJECT" render-window @1)"
assert_eq "" "$outside_render" "render is a silent no-op outside tmux"
missing_pane_output="$(env -u TMUX_PANE TMUX='test-socket' "$SUBJECT" set done)"
assert_eq "" "$missing_pane_output" "set is a silent no-op when TMUX_PANE is absent"

export TMUX="test-socket"
tmux new-session -d -s status-test
window_id="$(tmux display-message -p -t status-test:0 '#{window_id}')"
pane_one="$(tmux display-message -p -t status-test:0.0 '#{pane_id}')"
pane_two="$(tmux split-window -d -P -F '#{pane_id}' -t "$window_id")"

assert_fails "invalid state is rejected" env TMUX_PANE="$pane_one" "$SUBJECT" set 'done;display-message owned'
assert_fails "invalid pane id is rejected" env TMUX_PANE='%1;run-shell false' "$SUBJECT" set done
assert_fails "invalid window id is rejected" "$SUBJECT" render-window '@1;run-shell false'

TMUX_PANE="$pane_one" "$SUBJECT" set done
assert_eq "done" "$(tmux show-options -p -v -t "$pane_one" @ck_agent_status)" "state is owned by the targeted pane"
assert_eq "" "$(tmux show-options -p -q -v -t "$pane_two" @ck_agent_status)" "setting one pane leaves its sibling unchanged"
assert_eq " #[fg=#a6d189]󰄬#[fg=#c6d0f5]" "$("$SUBJECT" render-window "$window_id")" "done renders the Frappe green glyph"

TMUX_PANE="$pane_two" "$SUBJECT" set failed
assert_eq " #[fg=#e78284]󰅖#[fg=#c6d0f5]" "$("$SUBJECT" render-window "$window_id")" "failure outranks completion"

TMUX_PANE="$pane_one" "$SUBJECT" set needs-action
assert_eq " #[fg=#e5c890]󰋗#[fg=#c6d0f5]" "$("$SUBJECT" render-window "$window_id")" "needs-action has highest priority"

TMUX_PANE="$pane_one" "$SUBJECT" clear
assert_eq " #[fg=#e78284]󰅖#[fg=#c6d0f5]" "$("$SUBJECT" render-window "$window_id")" "clearing one pane exposes its sibling state"

TMUX_PANE="$pane_one" "$SUBJECT" set done
tmux kill-pane -t "$pane_two"
assert_eq " #[fg=#a6d189]󰄬#[fg=#c6d0f5]" "$("$SUBJECT" render-window "$window_id")" "killing a pane removes its contribution"

TMUX_PANE="$pane_one" "$SUBJECT" clear
assert_eq "" "$("$SUBJECT" render-window "$window_id")" "a window with no state renders no bytes"

stale_output="$(TMUX_PANE='%999999' "$SUBJECT" set done)"
assert_eq "" "$stale_output" "a stale but valid pane target is tolerated"

printf '1..%d\n' "$passed"
