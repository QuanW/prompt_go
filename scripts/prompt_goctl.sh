#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PID_FILE="${PROMPT_GO_PID_FILE:-$PROJECT_DIR/prompt_manager.pid}"
LOG_FILE="${PROMPT_GO_LOG_FILE:-$PROJECT_DIR/prompt_manager.log}"
CONFIG_DIR="${PROMPT_GO_CONFIG_DIR:-config}"
PROMPT_DIR="${PROMPT_GO_PROMPT_DIR:-prompt}"
LAUNCH_AGENT_LABEL="${PROMPT_GO_LAUNCH_AGENT_LABEL:-com.quanw.prompt-go}"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_PLIST="$LAUNCH_AGENTS_DIR/$LAUNCH_AGENT_LABEL.plist"
LAUNCH_DOMAIN="gui/$(id -u)"

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

pid_matches_app() {
  local pid="$1"
  local command
  command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  [[ "$command" == *"$PROJECT_DIR/main.py"* ]]
}

is_running() {
  local pid
  pid="$(read_pid || true)"
  [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null && pid_matches_app "$pid"
}

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

agent_installed() {
  is_macos && [[ -f "$LAUNCH_AGENT_PLIST" ]]
}

agent_loaded() {
  agent_installed && launchctl print "$LAUNCH_DOMAIN/$LAUNCH_AGENT_LABEL" >/dev/null 2>&1
}

agent_state() {
  if ! agent_loaded; then
    echo "not-loaded"
    return 0
  fi

  launchctl print "$LAUNCH_DOMAIN/$LAUNCH_AGENT_LABEL" 2>/dev/null \
    | awk -F'= ' '/state =/{print $2; exit}'
}

agent_running() {
  [[ "$(agent_state)" == "running" ]]
}

agent_bootstrap() {
  if ! agent_loaded; then
    launchctl bootstrap "$LAUNCH_DOMAIN" "$LAUNCH_AGENT_PLIST"
  fi
}

cleanup_stale_pid() {
  if agent_running; then
    return 0
  fi

  if [[ -f "$PID_FILE" ]] && ! is_running; then
    rm -f "$PID_FILE"
  fi
}

status() {
  local pid
  pid="$(read_pid || true)"

  if agent_running; then
    echo "running ${pid:-launchagent}"
  elif is_running; then
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

  if agent_installed; then
    cleanup_stale_pid
    agent_bootstrap
    launchctl kickstart -k "$LAUNCH_DOMAIN/$LAUNCH_AGENT_LABEL"

    for _ in {1..30}; do
      if is_running; then
        echo "Prompt GO started by LaunchAgent: $(read_pid)"
        return 0
      fi
      sleep 0.2
    done

    echo "LaunchAgent start failed or exited early; falling back to direct start." >&2
  fi

  start_direct
}

start_direct() {
  cleanup_stale_pid

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

  if ! is_running && ! agent_running; then
    [[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"
    echo "Prompt GO is not running."
    return 0
  fi

  if agent_installed && agent_running; then
    launchctl kill TERM "$LAUNCH_DOMAIN/$LAUNCH_AGENT_LABEL"
  elif [[ -n "${pid:-}" ]]; then
    kill -TERM "$pid"
  fi

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

plist_escape() {
  sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&apos;/g"
}

install_agent() {
  if ! is_macos; then
    echo "LaunchAgent is only available on macOS." >&2
    return 1
  fi

  if ! [[ -x "$PYTHON_BIN" ]]; then
    echo "Python not found or not executable: $PYTHON_BIN" >&2
    return 1
  fi

  mkdir -p "$LAUNCH_AGENTS_DIR"

  local project_dir_escaped python_bin_escaped config_dir_escaped prompt_dir_escaped
  local stdout_log_escaped stderr_log_escaped label_escaped
  project_dir_escaped="$(printf '%s' "$PROJECT_DIR" | plist_escape)"
  python_bin_escaped="$(printf '%s' "$PYTHON_BIN" | plist_escape)"
  config_dir_escaped="$(printf '%s' "$CONFIG_DIR" | plist_escape)"
  prompt_dir_escaped="$(printf '%s' "$PROMPT_DIR" | plist_escape)"
  stdout_log_escaped="$(printf '%s' "$PROJECT_DIR/launchd.stdout.log" | plist_escape)"
  stderr_log_escaped="$(printf '%s' "$PROJECT_DIR/launchd.stderr.log" | plist_escape)"
  label_escaped="$(printf '%s' "$LAUNCH_AGENT_LABEL" | plist_escape)"

  cat > "$LAUNCH_AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label_escaped</string>
  <key>WorkingDirectory</key>
  <string>$project_dir_escaped</string>
  <key>ProgramArguments</key>
  <array>
    <string>$python_bin_escaped</string>
    <string>$project_dir_escaped/main.py</string>
    <string>--config</string>
    <string>$config_dir_escaped</string>
    <string>--prompt</string>
    <string>$prompt_dir_escaped</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PYTHONUNBUFFERED</key>
    <string>1</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$stdout_log_escaped</string>
  <key>StandardErrorPath</key>
  <string>$stderr_log_escaped</string>
  <key>ProcessType</key>
  <string>Interactive</string>
</dict>
</plist>
PLIST

  if agent_loaded; then
    launchctl bootout "$LAUNCH_DOMAIN/$LAUNCH_AGENT_LABEL" >/dev/null 2>&1 || true
  fi

  launchctl bootstrap "$LAUNCH_DOMAIN" "$LAUNCH_AGENT_PLIST"
  echo "LaunchAgent installed: $LAUNCH_AGENT_PLIST"
  echo "Use '$0 start' to start Prompt GO, or log out/in for RunAtLoad."
}

uninstall_agent() {
  if ! agent_installed; then
    echo "LaunchAgent is not installed."
    return 0
  fi

  if agent_loaded; then
    launchctl bootout "$LAUNCH_DOMAIN/$LAUNCH_AGENT_LABEL" >/dev/null 2>&1 || true
  fi

  rm -f "$LAUNCH_AGENT_PLIST"
  echo "LaunchAgent uninstalled: $LAUNCH_AGENT_LABEL"
}

agent_status() {
  if ! agent_installed; then
    echo "not-installed"
    return 0
  fi

  if agent_loaded; then
    echo "loaded $(agent_state) $LAUNCH_AGENT_PLIST"
  else
    echo "installed $LAUNCH_AGENT_PLIST"
  fi
}

doctor() {
  echo "Prompt GO diagnostics"
  echo "Project: $PROJECT_DIR"
  echo "Python: $PYTHON_BIN"
  RESOLVED_PYTHON="$PYTHON_BIN"
  if command -v readlink >/dev/null 2>&1; then
    RESOLVED_PYTHON="$(readlink -f "$PYTHON_BIN" 2>/dev/null || printf '%s' "$PYTHON_BIN")"
  fi
  echo "Resolved Python: $RESOLVED_PYTHON"
  echo "Status: $(status)"
  echo "LaunchAgent: $(agent_status)"
  echo

  if is_macos; then
    echo "macOS permissions required for the app that starts Prompt GO:"
    echo "- Accessibility"
    echo "- Input Monitoring"
    echo
    echo "If started from SwiftBar, grant permissions to SwiftBar."
    echo "If started from LaunchAgent, macOS may require permissions for the Python executable."
    echo "If macOS still reports the process as untrusted, also add these Python executables:"
    echo "$PYTHON_BIN"
    if [[ "$RESOLVED_PYTHON" != "$PYTHON_BIN" ]]; then
      echo "$RESOLVED_PYTHON"
    fi
    echo
  fi

  if [[ -f "$LOG_FILE" ]]; then
    RECENT_LOG="$(tail -n 200 "$LOG_FILE" 2>/dev/null || true)"
    LAST_BACKEND="$(printf '%s
' "$RECENT_LOG" | awk '/全局快捷键监听器启动成功/ { line=$0 } END { print line }')"
    TRUST_WARNING_ACTIVE="$(printf '%s
' "$RECENT_LOG" | awk '
      /not trusted/ { warning = 1 }
      /触发快捷键:/ { warning = 0 }
      END { if (warning) print "yes" }
    ')"
    if [[ "$LAST_BACKEND" == *"后端: pynput"* ]] && [[ "$TRUST_WARNING_ACTIVE" == "yes" ]]; then
      echo "Recent log warning: input monitoring is not trusted."
      echo "Open System Settings -> Privacy & Security and update permissions, then fully quit and reopen the launcher app."
    else
      echo "No active pynput input-monitoring trust warning found in the recent log."
    fi
  else
    echo "Log file not found yet."
  fi

  if [[ -f "$PROJECT_DIR/launchd.stderr.log" ]] \
    && tail -n 80 "$PROJECT_DIR/launchd.stderr.log" | grep "Operation not permitted" | grep -q "$PROJECT_DIR"; then
    echo
    echo "Recent LaunchAgent permission error found."
    echo "macOS may block LaunchAgent/Python from reading the current project path."
    echo "Recommended fixes:"
    echo "- Move the project to a developer folder outside protected folders, then reinstall the agent."
    echo "- Or grant Full Disk Access / Files and Folders access to the Python executable shown above."
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
  install-agent)
    install_agent
    ;;
  uninstall-agent)
    uninstall_agent
    ;;
  agent-status)
    agent_status
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|reload|status|log|doctor|install-agent|uninstall-agent|agent-status}" >&2
    exit 2
    ;;
esac
