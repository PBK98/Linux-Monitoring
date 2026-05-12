#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[ERROR] setup.sh must be run as root."
  exit 1
fi

AGENT_HOME=/home/agent-admin/agent-app
SSH_PORT=${SSH_PORT:-20022}
AGENT_PORT=${AGENT_PORT:-15034}

# =========================
# Group Setup
# =========================

groupadd -f agent-admin
groupadd -f dev
groupadd -f agent-common

# =========================
# User Setup
# =========================

# test user
# primary group: dev
# secondary group: agent-admin
if ! id "test" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g dev -G agent-admin test
else
    usermod -g dev -aG agent-admin test
fi

# core user
# primary group: agent-common
if ! id "core" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g agent-common core
else
    usermod -g agent-common core
fi

# =========================
# Directory Setup
# =========================

mkdir -p \
  "$AGENT_HOME"/{upload_files,api_keys,bin} \
  /var/log/agent-app \
  /var/log/monitor/agent-app/archive

# =========================
# File Copy
# =========================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp "$SCRIPT_DIR/agent_app.py" "$AGENT_HOME/agent_app.py"
cp "$SCRIPT_DIR/monitor.sh" "$SCRIPT_DIR/report.sh" "$SCRIPT_DIR/log_archive.sh" "$AGENT_HOME/bin/"

chmod +x "$AGENT_HOME/agent_app.py"
chmod +x "$AGENT_HOME/bin/"*.sh

echo 'agent_api_key_test' > "$AGENT_HOME/api_keys/t_secret.key"

# =========================
# Permission Setup
# =========================

chown -R root:agent-common "$AGENT_HOME"

chown test:dev "$AGENT_HOME/upload_files"
chmod 770 "$AGENT_HOME/upload_files"

chgrp -R agent-common "$AGENT_HOME/api_keys" /var/log/agent-app
chmod 770 "$AGENT_HOME/api_keys" /var/log/agent-app

chmod 660 "$AGENT_HOME/api_keys/t_secret.key"

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
# SSH Setup
# =========================

if [[ -f /etc/ssh/sshd_config ]]; then
  sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config

  mkdir -p /var/run/sshd
fi

# =========================
# Cron Setup
# =========================

if command -v crontab >/dev/null 2>&1; then

  (
    crontab -u root -l 2>/dev/null | grep -v monitor.sh || true
    echo "* * * * * . /etc/profile.d/agent-app.sh; $AGENT_HOME/bin/monitor.sh >> /var/log/agent-app/cron.log 2>&1"
  ) | crontab -u root -

  (
    crontab -u root -l 2>/dev/null | grep -v log_archive.sh || true
    echo "0 3 * * * $AGENT_HOME/bin/log_archive.sh >> /var/log/agent-app/archive.log 2>&1"
  ) | crontab -u root -

fi

echo "Setup complete."