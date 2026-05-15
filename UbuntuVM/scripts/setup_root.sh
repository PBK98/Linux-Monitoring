#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[ERROR] setup_root.sh must be run as root."
  exit 1
fi

SSH_PORT=${SSH_PORT:-20022}
AGENT_PORT=${AGENT_PORT:-15034}
AGENT_HOME=/home/agent-admin/agent-app

apt update
apt install -y cron openssh-server ufw procps net-tools iproute2 gzip
apt clean

groupadd -f agent-common
groupadd -f agent-core

if ! id agent-admin >/dev/null 2>&1; then
  useradd -m -s /bin/bash -g agent-common -G agent-core agent-admin
else
  usermod -g agent-common -aG agent-core agent-admin
fi

if ! id agent-dev >/dev/null 2>&1; then
  useradd -m -s /bin/bash -g agent-common -G agent-core agent-dev
else
  usermod -g agent-common -aG agent-core agent-dev
fi

if ! id agent-test >/dev/null 2>&1; then
  useradd -m -s /bin/bash -g agent-common agent-test
else
  usermod -g agent-common agent-test
fi

mkdir -p "$AGENT_HOME"/{app,bin,api_keys,upload_files}
mkdir -p /var/log/agent-app
mkdir -p /var/log/monitor/agent-app/archive

chown -R agent-admin:agent-core "$AGENT_HOME"
chmod 750 /home/agent-admin
chmod 750 "$AGENT_HOME"

chown agent-test:agent-common "$AGENT_HOME/upload_files"
chmod 770 "$AGENT_HOME/upload_files"

chown -R agent-admin:agent-core "$AGENT_HOME/api_keys"
chmod 770 "$AGENT_HOME/api_keys"

chown -R agent-admin:agent-core /var/log/agent-app
chmod 770 /var/log/agent-app

chown -R agent-admin:agent-common /var/log/monitor
chmod -R 770 /var/log/monitor

cat > /etc/profile.d/agent-app.sh <<EOF
export AGENT_HOME=$AGENT_HOME
export AGENT_PORT=$AGENT_PORT
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
export AGENT_LOG_DIR=/var/log/agent-app
EOF

sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

systemctl daemon-reload || true
systemctl restart ssh || systemctl restart sshd

ufw allow "${SSH_PORT}/tcp" || true
ufw allow "${AGENT_PORT}/tcp" || true

systemctl enable cron || true
systemctl restart cron || true

echo "Root setup complete."
echo "Next: su - agent-admin and run setup_agent-admin.sh"