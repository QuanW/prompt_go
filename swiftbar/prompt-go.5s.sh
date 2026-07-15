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

case "$STATUS" in
  running*)
    PID="${STATUS#running }"
    echo "Prompt GO: running"
    echo "---"
    echo "PID: $PID"
    echo "Stop | bash=\"$CTL\" param1=stop terminal=false refresh=true"
    echo "Restart | bash=\"$CTL\" param1=restart terminal=false refresh=true"
    echo "Reload Config | bash=\"$CTL\" param1=reload terminal=false refresh=true"
    ;;
  stale*)
    PID="${STATUS#stale }"
    echo "Prompt GO: stale"
    echo "---"
    echo "Stale PID: $PID"
    echo "Start | bash=\"$CTL\" param1=start terminal=false refresh=true"
    echo "Restart | bash=\"$CTL\" param1=restart terminal=false refresh=true"
    ;;
  stopped)
    echo "Prompt GO: stopped"
    echo "---"
    echo "Start | bash=\"$CTL\" param1=start terminal=false refresh=true"
    ;;
  *)
    echo "Prompt GO: error"
    echo "---"
    echo "Status command failed"
    ;;
esac

echo "---"
echo "Open Project | bash=open param1=\"$PROMPT_GO_DIR\" terminal=false"
echo "Open Log | bash=open param1=\"$LOG_FILE\" terminal=false"
echo "Tail Log | bash=\"$CTL\" param1=log terminal=true refresh=false"
