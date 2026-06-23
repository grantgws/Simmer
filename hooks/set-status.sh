#!/bin/bash
# Simmer status writer — called by Claude Code hooks. Writes THIS session's
# state to its own file (keyed by session_id) so concurrent sessions don't
# clobber. Also records the terminal's tty + app so the menu bar can focus the
# right tab when you click a session. Claude pipes the event JSON to stdin.
#
# Usage: set-status.sh <arg>
#   working | done | idle  -> write that state
#   notify                 -> only a permission/approval prompt becomes "action";
#                             all other notifications are ignored (no false alarms).
#   end                    -> session closed: delete its file.
ARG="${1:-idle}"

# Find the controlling terminal by walking up the process tree (stdin is a pipe
# here, so `tty` won't work, but an ancestor owns the real ttysNNN).
get_tty() {
  local pid=$$ t
  for _ in 1 2 3 4 5 6; do
    [ -z "$pid" ] && break
    t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    case "$t" in
      ""|"??") ;;
      *) printf '%s' "$t"; return ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
}

SIMMER_TTY="$(get_tty)" python3 -c '
import sys, json, os, time
arg = sys.argv[1]
raw = sys.stdin.read()
try:
    d = json.loads(raw) if raw.strip() else {}
except Exception:
    d = {}
sid = d.get("session_id") or "default"
cwd = d.get("cwd") or ""
dd = os.path.expanduser("~/.claude/simmer/sessions")
path = os.path.join(dd, sid + ".json")

if arg == "end":
    try:
        os.remove(path)
    except OSError:
        pass
    sys.exit(0)

state = arg
if arg == "notify":
    # Only a genuine permission/approval request counts as "action needed".
    # Every other notification (idle "waiting for your input", etc.) is ignored,
    # so the menu bar does not cry wolf.
    msg = (d.get("message") or "").lower()
    if ("permission" in msg) or ("approve" in msg) or ("wants to" in msg):
        state = "action"
    else:
        sys.exit(0)

tty = os.environ.get("SIMMER_TTY") or ""
term = os.environ.get("TERM_PROGRAM") or ""
# Keep tty/term stable if a later event could not recapture them.
if (not tty or not term) and os.path.exists(path):
    try:
        old = json.load(open(path))
        tty = tty or old.get("tty", "")
        term = term or old.get("term", "")
    except Exception:
        pass

os.makedirs(dd, exist_ok=True)
with open(path, "w") as f:
    json.dump({"state": state, "ts": int(time.time()), "cwd": cwd, "tty": tty, "term": term}, f)
' "$ARG"
exit 0
