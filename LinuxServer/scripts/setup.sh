#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[ERROR] setup.sh must be run as root."
  echo "Docker example: docker exec -it -u root linux-server bash"
  exit 1
fi

AGENT_HOME=/home/agent-admin/agent-app
SSH_PORT=${SSH_PORT:-20022}
AGENT_PORT=${AGENT_PORT:-15034}

groupadd -f agent-admin
groupadd -f dev
groupadd -f agent-common

# test user: primary group dev, secondary group agent-admin
if ! id "test" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g dev -G agent-admin test
else
    usermod -g dev -aG agent-admin test
fi

# core user: primary group agent-common
if ! id "core" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g agent-common core
else
    usermod -g agent-common core
fi

usermod -aG agent-common,agent-core agent-admin
usermod -aG agent-common,agent-core agent-dev
usermod -aG agent-common agent-test

mkdir -p "$AGENT_HOME"/{upload_files,api_keys,bin} \
  /var/log/agent-app \
  /var/log/monitor/agent-app/archive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -f "$PROJECT_DIR/app/agent_app.py" ]]; then
  cp "$PROJECT_DIR/app/agent_app.py" "$AGENT_HOME/agent_app.py"
elif [[ -f "/app/agent_app.py" ]]; then
  cp "/app/agent_app.py" "$AGENT_HOME/agent_app.py"
else
  echo "[ERROR] agent_app.py not found."
  exit 1
fi

cp "$SCRIPT_DIR/monitor.sh" "$SCRIPT_DIR/report.sh" "$SCRIPT_DIR/log_archive.sh" "$AGENT_HOME/bin/"
chmod +x "$AGENT_HOME/agent_app.py" "$AGENT_HOME/bin/"*.sh

echo 'agent_api_key_test' > "$AGENT_HOME/api_keys/t_secret.key"

chown -R agent-admin:agent-common "$AGENT_HOME"
chgrp agent-common "$AGENT_HOME/upload_files"
chmod 770 "$AGENT_HOME/upload_files"

chgrp -R agent-core "$AGENT_HOME/api_keys" /var/log/agent-app
chmod 770 "$AGENT_HOME/api_keys" /var/log/agent-app
chmod 660 "$AGENT_HOME/api_keys/t_secret.key"

chown agent-admin:agent-core "$AGENT_HOME/bin/monitor.sh" "$AGENT_HOME/bin/report.sh" "$AGENT_HOME/bin/log_archive.sh"
chmod 750 "$AGENT_HOME/bin/monitor.sh" "$AGENT_HOME/bin/report.sh" "$AGENT_HOME/bin/log_archive.sh"
chown -R agent-admin:agent-core /var/log/monitor
chmod -R 770 /var/log/monitor

cat > /etc/profile.d/agent-app.sh <<ENVEOF
export AGENT_HOME=$AGENT_HOME
export AGENT_PORT=$AGENT_PORT
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
export AGENT_LOG_DIR=/var/log/agent-app
ENVEOF

if [[ -f /etc/ssh/sshd_config ]]; then
  if grep -Eq '^#?Port ' /etc/ssh/sshd_config; then
    sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
  else
    echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
  fi

  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  mkdir -p /var/run/sshd
fi

if command -v ufw >/dev/null 2>&1; then
  ufw allow "${SSH_PORT}/tcp" || true
  ufw allow "${AGENT_PORT}/tcp" || true
elif command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --permanent --add-port="${SSH_PORT}/tcp" || true
  firewall-cmd --permanent --add-port="${AGENT_PORT}/tcp" || true
  firewall-cmd --reload || true
fi

if command -v crontab >/dev/null 2>&1; then
  ( crontab -u agent-admin -l 2>/dev/null | grep -v 'monitor.sh' || true; \
    echo '* * * * * . /etc/profile.d/agent-app.sh; /home/agent-admin/agent-app/bin/monitor.sh >> /var/log/agent-app/cron.log 2>&1' ) | crontab -u agent-admin -

  ( crontab -u agent-admin -l 2>/dev/null | grep -v 'log_archive.sh' || true; \
    echo '0 3 * * * /home/agent-admin/agent-app/bin/log_archive.sh >> /var/log/agent-app/archive.log 2>&1' ) | crontab -u agent-admin -
fi

cat <<MSG
Setup complete.

Run agent app:
  su - agent-admin -c 'source /etc/profile.d/agent-app.sh && cd /home/agent-admin/agent-app && nohup python3 agent_app.py > /tmp/agent_app.log 2>&1 &'

Start SSH service:
  service ssh start

SSH port in container: $SSH_PORT
Agent port: $AGENT_PORT
MSG
