#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -un)" != "agent-admin" ]]; then
  echo "[ERROR] setup.sh must be run as agent-admin."
  exit 1
fi

# =========================
# Permission Setup
# =========================

AGENT_HOME=/home/agent-admin/agent-app

chown -R root:agent-common "$AGENT_HOME"

chgrp agent-core /home/agent-admin
chmod 750 /home/agent-admin

chgrp agent-core "$AGENT_HOME"
chmod 750 "$AGENT_HOME"

chown agent-test:agent-common "$AGENT_HOME/upload_files"
chmod 770 "$AGENT_HOME/upload_files"

chgrp -R agent-core "$AGENT_HOME/api_keys" /var/log/agent-app
chmod 770 "$AGENT_HOME/api_keys" /var/log/agent-app
chmod 660 "$AGENT_HOME/api_keys/t_secret.key"

touch /var/log/agent-app/monitor.log
chown root:agent-core /var/log/agent-app/monitor.log
chmod 660 /var/log/agent-app/monitor.log

chown -R root:agent-common "$AGENT_HOME/bin"
chmod 750 "$AGENT_HOME/bin/"*.sh

chown -R root:agent-common /var/log/monitor
chmod -R 770 /var/log/monitor

# =========================
# Environment Variables
# =========================

cat > /etc/profile.d/agent-app.sh <<ENVEOF
export AGENT_HOME=$AGENT_HOME
export AGENT_PORT=$AGENT_PORT
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
export AGENT_LOG_DIR=/var/log/agent-app
ENVEOF


# =========================
# Cron Setup
# =========================

if command -v crontab >/dev/null 2>&1; then

  (
    crontab -u agent-admin -l 2>/dev/null | grep -v monitor.sh || true
    echo "* * * * * . /etc/profile.d/agent-app.sh; $AGENT_HOME/bin/monitor.sh >> /var/log/agent-app/cron.log 2>&1"
  ) | crontab -u agent-admin -

  (
    crontab -u agent-admin -l 2>/dev/null | grep -v log_archive.sh || true
    echo "0 3 * * * $AGENT_HOME/bin/log_archive.sh >> /var/log/agent-app/archive.log 2>&1"
  ) | crontab -u agent-admin -

fi

# =========================
  # Start Services
  # =========================

  service ssh restart 2>/dev/null || service ssh start
  service cron restart 2>/dev/null || service cron start

# =========================
# Runtime Permission Setup
# =========================

chgrp agent-core /home/agent-admin
chmod 750 /home/agent-admin

chgrp agent-core "$AGENT_HOME"
chmod 750 "$AGENT_HOME"

chgrp -R agent-core "$AGENT_HOME/api_keys"
chmod 750 "$AGENT_HOME/api_keys"
chmod 640 "$AGENT_HOME/api_keys/t_secret.key"

chgrp -R agent-common /var/log/agent-app
chmod 770 /var/log/agent-app

touch /var/log/agent-app/monitor.log
chown root:agent-common /var/log/agent-app/monitor.log
chmod 660 /var/log/agent-app/monitor.log

touch /tmp/agent_app.log
chown agent-admin:agent-common /tmp/agent_app.log
chmod 664 /tmp/agent_app.log

# =========================
# Start Agent App as test
# =========================

source /etc/profile.d/agent-app.sh

if ! pgrep -f "./agent-app" >/dev/null 2>&1; then
  cd "$PROJECT_HOME"
  nohup ./agent-app >> /tmp/agent_app.log 2>&1 < /dev/null &
fi

cat <<MSG

Setup complete.

SSH:
  Container SSH port : $SSH_PORT
  SSH login example  : ssh agent-admin@localhost -p 20022

Agent:
  Agent port         : $AGENT_PORT
  Agent log          : /tmp/agent_app.log
  Monitor log        : /var/log/agent-app/monitor.log

MSG
