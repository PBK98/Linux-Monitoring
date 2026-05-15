#!/usr/bin/env bash

# =========================
#  Check root user
# =========================

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[ERROR] setup_root.sh must be run as root."
  exit 1
fi

# =========================
#  Pre-setup (install packages)
# =========================

apt update && apt install -y \
    python3 \
    python3-pip \
    cron \
    sudo \
    procps \
    net-tools \
    iproute2 \
    vim \
    gzip \
    openssh-server \
    ufw \
    && apt clean

SSH_PORT=${SSH_PORT:-20022}
AGENT_PORT=${AGENT_PORT:-15034}

# =========================
# Group Setup
# =========================

groupadd -f agent-core
groupadd -f agent-common

# =========================
# User Setup
# =========================

# agent admin user
# primary group: agent-common
# secondary group: agent-core
if ! id "agent-admin" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g agent-common -G agent-core agent-admin
else
    usermod -g agent-common -aG agent-core agent-admin
fi

# agent-dev user
# primary group: agent-core
# secondary group: agent-admin
if ! id "agent-dev" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g agent-common -G agent-core agent-dev
else
    usermod -g agent-common -aG agent-core agent-dev
fi

# agent-test user
# primary group: agent-common
if ! id "agent-test" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g agent-common agent-test
else
    usermod -g agent-common agent-test
fi

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
    echo "agent-admin:${SSH_PASSWORD}" | chpasswd
  fi

  service ssh restart 2>/dev/null || service ssh start

else
  echo "[WARN] /etc/ssh/sshd_config not found. Check Dockerfile openssh-server installation."
fi

systemctl daemon-reload
systemctl stop ssh.socket
systemctl disable ssh.socket
systemctl restart ssh


# =========================
# Firewall Setup
# =========================

if command -v ufw >/dev/null 2>&1; then

  echo "[INFO] UFW found. Applying allow rules only."

  ufw --force enable

  ufw allow "${SSH_PORT}/tcp" || true
  ufw allow "${AGENT_PORT}/tcp" || true

  echo "[INFO] UFW rules applied."

elif command -v firewall-cmd >/dev/null 2>&1; then
  echo "[WARN] UFW is not found Apply firewall."

  firewall-cmd --permanent --add-port="${SSH_PORT}/tcp" || true
  firewall-cmd --permanent --add-port="${AGENT_PORT}/tcp" || true
  firewall-cmd --reload || true

  echo "[INFO] firewalld rules applied."

else

  echo "[WARN] No firewall service found."

fi

AGENT_HOME=/home/agent-admin/agent-app

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
PROJECT_DIR="$(cd "$SCRIPT_DIR/../app" && pwd)"

cp "$PROJECT_DIR/agent-app" "$AGENT_HOME/agent-app"
cp "$SCRIPT_DIR/monitor.sh" "$SCRIPT_DIR/report.sh" "$SCRIPT_DIR/log_archive.sh" "$AGENT_HOME/bin/"

chmod +x "$AGENT_HOME/agent-app"
chmod +x "$AGENT_HOME/bin/"*.sh

echo 'agent_api_key_test' > "$AGENT_HOME/api_keys/t_secret.key"