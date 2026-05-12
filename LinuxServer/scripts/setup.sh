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
  if grep -Eq '^#?Port ' /etc/ssh/sshd_config; then
    sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
  else
    echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
  fi

  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

  mkdir -p /var/run/sshd

  if [[ -n "${SSH_PASSWORD:-}" ]]; then
    echo "test:${SSH_PASSWORD}" | chpasswd
  fi

  service ssh restart 2>/dev/null || service ssh start
else
  echo "[WARN] /etc/ssh/sshd_config not found. Check Dockerfile openssh-server installation."
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

# =========================
  # Start Services
  # =========================

  service ssh restart 2>/dev/null || service ssh start
  service cron restart 2>/dev/null || service cron start

# =========================
# Runtime Permission Setup
# =========================

chgrp agent-admin /home/agent-admin
chmod 750 /home/agent-admin

chgrp agent-admin "$AGENT_HOME"
chmod 750 "$AGENT_HOME"

chgrp -R agent-admin "$AGENT_HOME/api_keys"
chmod 750 "$AGENT_HOME/api_keys"
chmod 640 "$AGENT_HOME/api_keys/t_secret.key"

chgrp -R agent-admin /var/log/agent-app
chmod 770 /var/log/agent-app

touch /var/log/agent-app/monitor.log
chown root:agent-admin /var/log/agent-app/monitor.log
chmod 660 /var/log/agent-app/monitor.log

touch /tmp/agent_app.log
chown test:dev /tmp/agent_app.log
chmod 664 /tmp/agent_app.log

chgrp agent-admin /home/agent-admin
chmod 750 /home/agent-admin

chgrp agent-admin /home/agent-admin/agent-app
chmod 750 /home/agent-admin/agent-app

chgrp agent-admin /home/agent-admin/agent-app/api_keys
chmod 750 /home/agent-admin/agent-app/api_keys

chgrp agent-admin /home/agent-admin/agent-app/api_keys/t_secret.key
chmod 640 /home/agent-admin/agent-app/api_keys/t_secret.key

# =========================
# Start Agent App as test
# =========================

if ! pgrep -f "agent_app.py" >/dev/null 2>&1; then
  su - test -c "source /etc/profile.d/agent-app.sh && cd /app && nohup python3 agent_app.py > /tmp/agent_app.log 2>&1 &"
fi

cat <<MSG

Setup complete.

SSH:
  Container SSH port : $SSH_PORT
  Docker run example : docker run -dit -p 20022:$SSH_PORT --name linux-server linux-assignment
  SSH login example  : ssh test@localhost -p 20022

Agent:
  Agent port         : $AGENT_PORT
  Agent log          : /tmp/agent_app.log
  Monitor log        : /var/log/agent-app/monitor.log

MSG
