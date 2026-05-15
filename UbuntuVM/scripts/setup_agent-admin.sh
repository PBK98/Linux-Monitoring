#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -un)" != "agent-admin" ]]; then
  echo "[ERROR] setup_agent-admin.sh must be run as agent-admin."
  exit 1
fi

source /etc/profile.d/agent-app.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cp "$PROJECT_DIR/app/agent-app" "$AGENT_HOME/app/agent-app"
cp "$SCRIPT_DIR/monitor.sh" "$SCRIPT_DIR/report.sh" "$SCRIPT_DIR/log_archive.sh" "$AGENT_HOME/bin/"

chmod +x "$AGENT_HOME/app/agent-app"
chmod +x "$AGENT_HOME/bin/"*.sh

echo 'agent_api_key_test' > "$AGENT_HOME/api_keys/t_secret.key"
chmod 660 "$AGENT_HOME/api_keys/t_secret.key"

touch /tmp/agent_app.log
chmod 664 /tmp/agent_app.log

crontab -l 2>/dev/null | grep -v monitor.sh | crontab - || true
(
  crontab -l 2>/dev/null || true
  echo "* * * * * . /etc/profile.d/agent-app.sh; $AGENT_HOME/bin/monitor.sh >> /var/log/agent-app/cron.log 2>&1"
) | crontab -

crontab -l 2>/dev/null | grep -v log_archive.sh | crontab - || true
(
  crontab -l 2>/dev/null || true
  echo "0 3 * * * $AGENT_HOME/bin/log_archive.sh >> /var/log/agent-app/archive.log 2>&1"
) | crontab -

if ! pgrep -f "$AGENT_HOME/app/agent-app" >/dev/null 2>&1; then
  cd "$AGENT_HOME/app"
  nohup ./agent-app >> /tmp/agent_app.log 2>&1 < /dev/null &
fi

echo "Agent-admin setup complete."
echo "Check:"
echo "  ps -ef | grep agent-app"
echo "  $AGENT_HOME/bin/monitor.sh"