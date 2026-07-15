#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PID_FILE="${PROMPT_GO_PID_FILE:-$PROJECT_DIR/prompt_manager.pid}"
LOG_FILE="${PROMPT_GO_LOG_FILE:-$PROJECT_DIR/prompt_manager.log}"
CONFIG_DIR="${PROMPT_GO_CONFIG_DIR:-config}"
PROMPT_DIR="${PROMPT_GO_PROMPT_DIR:-prompt}"

if [[ -x "$PROJECT_DIR/.venv/bin/python" ]]; then
  PYTHON_BIN="${PROMPT_GO_PYTHON:-$PROJECT_DIR/.venv/bin/python}"
else
  PYTHON_BIN="${PROMPT_GO_PYTHON:-python3}"
fi

read_pid() {
  if [[ -f "$PID_FILE" ]]; then
    tr -d '[:space:]' < "$PID_FILE"
  fi
}

is_running() {
  local pid
  pid="$(read_pid || true)"
  [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null
}

status() {
  local pid
  pid="$(read_pid || true)"

  if is_running; then
    echo "running ${pid}"
  elif [[ -n "${pid:-}" ]]; then
    echo "stale ${pid}"
  else
    echo "stopped"
  fi
}

start() {
  if is_running; then
    echo "Prompt GO is already running: $(read_pid)"
    return 0
  fi

  if [[ -f "$PID_FILE" ]]; then
    rm -f "$PID_FILE"
  fi

  if ! command -v "$PYTHON_BIN" >/dev/null 2>&1 && [[ ! -x "$PYTHON_BIN" ]]; then
    echo "Python not found: $PYTHON_BIN" >&2
    return 1
  fi

  mkdir -p "$(dirname "$LOG_FILE")"

  (
    cd "$PROJECT_DIR"
    nohup "$PYTHON_BIN" "$PROJECT_DIR/main.py" \
      --config "$CONFIG_DIR" \
      --prompt "$PROMPT_DIR" \
      >> "$LOG_FILE" 2>&1 &
  )

  for _ in {1..20}; do
    if is_running; then
      echo "Prompt GO started: $(read_pid)"
      return 0
    fi
    sleep 0.2
  done

  echo "Prompt GO start requested, but no running PID was observed yet." >&2
  return 1
}

stop() {
  local pid
  pid="$(read_pid || true)"

  if ! is_running; then
    [[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"
    echo "Prompt GO is not running."
    return 0
  fi

  kill -TERM "$pid"

  for _ in {1..50}; do
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$PID_FILE"
      echo "Prompt GO stopped."
      return 0
    fi
    sleep 0.2
  done

  echo "Prompt GO did not stop within timeout: $pid" >&2
  return 1
}

reload_config() {
  local pid
  pid="$(read_pid || true)"

  if ! is_running; then
    echo "Prompt GO is not running."
    return 1
  fi

  kill -HUP "$pid"
  echo "Prompt GO reload signal sent: $pid"
}

restart() {
  stop
  start
}

doctor() {
  echo "Prompt GO diagnostics"
  echo "Project: $PROJECT_DIR"
  echo "Python: $PYTHON_BIN"
  echo "Status: $(status)"
  echo

  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macOS permissions required for the app that starts Prompt GO:"
    echo "- Accessibility"
    echo "- Input Monitoring"
    echo
    echo "If started from SwiftBar, grant permissions to SwiftBar."
    echo "If macOS still reports the process as untrusted, also add this Python executable:"
    echo "$PYTHON_BIN"
    echo
  fi

  if [[ -f "$LOG_FILE" ]] && tail -n 200 "$LOG_FILE" | grep -qi "not trusted"; then
    echo "Recent log warning: input monitoring is not trusted."
    echo "Open System Settings -> Privacy & Security and update permissions, then fully quit and reopen the launcher app."
  else
    echo "No recent input-monitoring trust warning found in the log."
  fi
}

case "${1:-status}" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  reload)
    reload_config
    ;;
  status)
    status
    ;;
  log)
    tail -n "${2:-80}" "$LOG_FILE"
    ;;
  doctor)
    doctor
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|reload|status|log|doctor}" >&2
    exit 2
    ;;
esac
