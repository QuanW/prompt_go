#!/usr/bin/env bash

PROMPT_GO_DIR="${PROMPT_GO_DIR:-/Users/wquan/Downloads/softwares/prompt_go}"
CTL="$PROMPT_GO_DIR/scripts/prompt_goctl.sh"
LOG_FILE="$PROMPT_GO_DIR/prompt_manager.log"

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

if [[ -f "$LOG_FILE" ]] && tail -n 200 "$LOG_FILE" | grep -qi "not trusted"; then
  PERMISSION_WARNING="yes"
fi

case "$STATUS" in
  running*)
    PID="${STATUS#running }"
    if [[ "$PERMISSION_WARNING" == "yes" ]]; then
      echo "Prompt GO: permissions"
    else
      echo "Prompt GO: running"
    fi
    echo "---"
    echo "PID: $PID"
    echo "Agent: $AGENT_STATUS"
    if [[ "$PERMISSION_WARNING" == "yes" ]]; then
      echo "Keyboard permission may be missing"
      echo "Run Doctor | bash=\"$CTL\" param1=doctor terminal=true refresh=false"
      echo "---"
    fi
    echo "Stop | bash=\"$CTL\" param1=stop terminal=false refresh=true"
    echo "Restart | bash=\"$CTL\" param1=restart terminal=false refresh=true"
    echo "Reload Config | bash=\"$CTL\" param1=reload terminal=false refresh=true"
    ;;
  stale*)
    PID="${STATUS#stale }"
    echo "Prompt GO: stale"
    echo "---"
    echo "Stale PID: $PID"
    echo "Agent: $AGENT_STATUS"
    echo "Start | bash=\"$CTL\" param1=start terminal=false refresh=true"
    echo "Restart | bash=\"$CTL\" param1=restart terminal=false refresh=true"
    ;;
  stopped)
    echo "Prompt GO: stopped"
    echo "---"
    echo "Agent: $AGENT_STATUS"
    echo "Start | bash=\"$CTL\" param1=start terminal=false refresh=true"
    ;;
  *)
    echo "Prompt GO: error"
    echo "---"
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
