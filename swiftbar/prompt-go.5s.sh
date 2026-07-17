#!/usr/bin/env bash

PROMPT_GO_DIR="${PROMPT_GO_DIR:-/Users/wquan/Developer/prompt_go}"
CTL="$PROMPT_GO_DIR/scripts/prompt_goctl.sh"
LOG_FILE="$PROMPT_GO_DIR/prompt_manager.log"
STATUS_FILE="$PROMPT_GO_DIR/runtime/status.json"

if [[ ! -x "$CTL" ]]; then
  echo "Prompt GO: setup needed"
  echo "---"
  echo "Control script is not executable"
  echo "$CTL"
  exit 0
fi

STATUS="$("$CTL" status 2>/dev/null || echo "error")"
AGENT_STATUS="$("$CTL" agent-status 2>/dev/null || echo "unknown")"
PERMISSION_WARNING=""

MODEL="unknown"
API_CONFIGURED="unknown"
LAST_TRIGGER="none"
LAST_ERROR_TYPE=""
if [[ -f "$STATUS_FILE" ]]; then
  STATUS_LINES="$(/usr/bin/python3 - "$STATUS_FILE" <<'PY' 2>/dev/null || true
import json
import sys
from pathlib import Path
try:
    data = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
except Exception:
    raise SystemExit(0)
providers = data.get('api', {}).get('providers', {})
configured = [name for name, cfg in providers.items() if cfg.get('configured')]
model = (data.get('model') or {}).get('name') or 'unknown'
trigger = data.get('last_trigger') or {}
error = data.get('last_error') or {}
print(f"MODEL={model}")
print(f"API_CONFIGURED={','.join(configured) if configured else 'none'}")
if trigger:
    print(f"LAST_TRIGGER={(trigger.get('status') or 'unknown')}:{(trigger.get('template') or 'unknown')}")
if error:
    print(f"LAST_ERROR_TYPE={error.get('type') or ''}")
PY
)"
  while IFS='=' read -r key value; do
    case "$key" in
      MODEL) MODEL="$value" ;;
      API_CONFIGURED) API_CONFIGURED="$value" ;;
      LAST_TRIGGER) LAST_TRIGGER="$value" ;;
      LAST_ERROR_TYPE) LAST_ERROR_TYPE="$value" ;;
    esac
  done <<< "$STATUS_LINES"
fi

if [[ -f "$LOG_FILE" ]]; then
  RECENT_LOG="$(tail -n 200 "$LOG_FILE" 2>/dev/null || true)"
  TRUST_WARNING_ACTIVE="$(printf '%s\n' "$RECENT_LOG" | awk '
    /not trusted|辅助功能权限未授予|权限未授予/ { warning = 1 }
    /全局快捷键监听器启动成功|触发快捷键:/ { warning = 0 }
    END { if (warning) print "yes" }
  ')"
  if [[ "$TRUST_WARNING_ACTIVE" == "yes" ]]; then
    PERMISSION_WARNING="yes"
  fi
fi

case "$STATUS" in
  running*)
    PID="${STATUS#running }"
    if [[ "$PERMISSION_WARNING" == "yes" ]]; then
      echo "● Prompt GO | color=#FF9F0A size=10"
      STATUS_LABEL="permissions"
      STATUS_COLOR="orange"
    else
      echo "● Prompt GO | color=#30D158 size=10"
      STATUS_LABEL="running"
      STATUS_COLOR="green"
    fi
    echo "---"
    echo "Status: $STATUS_LABEL | color=$STATUS_COLOR"
    echo "PID: $PID"
    echo "Model: $MODEL"
    echo "API: $API_CONFIGURED"
    echo "Last: $LAST_TRIGGER"
    if [[ -n "$LAST_ERROR_TYPE" ]]; then
      echo "Last error: $LAST_ERROR_TYPE | color=orange"
    fi
    echo "Agent: $AGENT_STATUS"
    if [[ "$PERMISSION_WARNING" == "yes" ]]; then
      echo "Keyboard permission may be missing | color=orange"
      echo "Run Doctor | bash=\"$CTL\" param1=doctor terminal=true refresh=false"
      echo "---"
    fi
    echo "Stop | bash=\"$CTL\" param1=stop terminal=false refresh=true"
    echo "Restart | bash=\"$CTL\" param1=restart terminal=false refresh=true"
    echo "Reload Config | bash=\"$CTL\" param1=reload terminal=false refresh=true"
    ;;
  stale*)
    PID="${STATUS#stale }"
    echo "● Prompt GO | color=#FF9F0A size=10"
    echo "---"
    echo "Status: stale PID | color=orange"
    echo "Stale PID: $PID"
    echo "Agent: $AGENT_STATUS"
    echo "Start | bash=\"$CTL\" param1=start terminal=false refresh=true"
    echo "Restart | bash=\"$CTL\" param1=restart terminal=false refresh=true"
    ;;
  stopped)
    echo "● Prompt GO | color=#FF453A size=10"
    echo "---"
    echo "Status: stopped | color=red"
    echo "Agent: $AGENT_STATUS"
    echo "Start | bash=\"$CTL\" param1=start terminal=false refresh=true"
    ;;
  *)
    echo "● Prompt GO | color=#FF453A size=10"
    echo "---"
    echo "Status: error | color=red"
    echo "Status command failed"
    ;;
esac
echo "---"
case "$AGENT_STATUS" in
  not-installed)
    echo "Install LaunchAgent | bash=\"$CTL\" param1=install-agent terminal=true refresh=true"
    ;;
  *)
    echo "Uninstall LaunchAgent | bash=\"$CTL\" param1=uninstall-agent terminal=true refresh=true"
    ;;
esac
echo "Doctor | bash=\"$CTL\" param1=doctor terminal=true refresh=false"
echo "Open Project | bash=open param1=\"$PROMPT_GO_DIR\" terminal=false"
echo "Open Log | bash=open param1=\"$LOG_FILE\" terminal=false"
echo "Tail Log | bash=\"$CTL\" param1=log terminal=true refresh=false"
