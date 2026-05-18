#!/usr/bin/env bash

# =========================
# Root Privilege Check
# =========================
# This script must be run as root.
# It performs system-level setup:
# - package installation
# - user/group creation
# - ssh configuration
# - directory and permission setup

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[ERROR] setup_root.sh must be run as root."
  exit 1
fi

# =========================
# Variables
# =========================

SSH_PORT=${SSH_PORT:-20022}
AGENT_PORT=${AGENT_PORT:-15034}
AGENT_HOME=/home/agent-admin/agent-app

# =========================
# Package Installation
# =========================
# Install required packages for:
# - ssh
# - cron
# - monitoring
# - networking
# - compression

apt update

apt install -y \
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
    rsync \
    ufw

apt clean

# =========================
# Group Setup
# =========================
# agent-common:
#   shared by admin/dev/test
#
# agent-core:
#   shared by admin/dev

groupadd -f agent-common
groupadd -f agent-core

# =========================
# User Setup
# =========================

# agent-admin
# primary group   : agent-common
# secondary group : agent-core

if ! id agent-admin >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g agent-common -G agent-core agent-admin
else
    usermod -g agent-common -aG agent-core agent-admin
fi

# agent-dev
# primary group   : agent-common
# secondary group : agent-core

if ! id agent-dev >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g agent-common -G agent-core agent-dev
else
    usermod -g agent-common -aG agent-core agent-dev
fi

# agent-test
# primary group : agent-common

if ! id agent-test >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g agent-common agent-test
else
    usermod -g agent-common agent-test
fi

# =========================
# Directory Setup
# =========================
# Create application directories:
#
# app          : executable binary
# bin          : shell scripts
# api_keys     : secret key files
# upload_files : upload directory

mkdir -p \
  "$AGENT_HOME"/{app,bin,api_keys,upload_files} \
  /var/log/agent-app \
  /var/log/monitor/agent-app/archive

# =========================
# Permission Setup
# =========================

# agent-admin home directory
chown agent-admin:agent-core /home/agent-admin
chmod 750 /home/agent-admin

# agent-app root directory
chown -R agent-admin:agent-core "$AGENT_HOME"
chmod 750 "$AGENT_HOME"

# upload directory
chown agent-test:agent-common "$AGENT_HOME/upload_files"
chmod 770 "$AGENT_HOME/upload_files"

# api_keys directory
chown -R agent-admin:agent-core "$AGENT_HOME/api_keys"
chmod 770 "$AGENT_HOME/api_keys"

# application logs
chown -R agent-admin:agent-core /var/log/agent-app
chmod 770 /var/log/agent-app

# monitor logs
chown -R agent-admin:agent-common /var/log/monitor
chmod -R 770 /var/log/monitor

# =========================
# Environment Variables
# =========================
# Create global environment variables
# used by monitoring scripts and agent-app

cat > /etc/profile.d/agent-app.sh <<EOF
export AGENT_HOME=$AGENT_HOME
export AGENT_PORT=$AGENT_PORT
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
export AGENT_LOG_DIR=/var/log/agent-app
EOF

chmod 644 /etc/profile.d/agent-app.sh

# =========================
# SSH Setup
# =========================
# - change ssh port
# - enable password login
# - disable root ssh login

if [[ -f /etc/ssh/sshd_config ]]; then

  if grep -Eq '^#?Port ' /etc/ssh/sshd_config; then
    sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
  else
    echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
  fi

  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config

  sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

  mkdir -p /var/run/sshd

fi

# Restart SSH service
systemctl daemon-reload || true
systemctl restart ssh || systemctl restart sshd

# =========================
# Firewall Setup
# =========================
# Allow SSH and agent-app ports

if command -v ufw >/dev/null 2>&1; then

  ufw allow "${SSH_PORT}/tcp" || true
  ufw allow "${AGENT_PORT}/tcp" || true
  ufw enable || true
fi

# =========================
# Cron Service Setup
# =========================

systemctl enable cron || true
systemctl restart cron || true

# =========================
# Move Linux-Monitoring Directory
# =========================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

rsync -av --exclude='setup_root.sh' "$SCRIPT_DIR/" "$AGENT_HOME/bin/"
rsync -av "$PROJECT_DIR/app/" "$AGENT_HOME/app/"
chown -R agent-admin:agent-core "$AGENT_HOME"/{app,bin}

# =========================
# Setup Complete
# =========================

cat <<MSG

setup_root.sh completed.

Next step:

  su - agent-admin

Run:

  ./setup_agent-admin.sh

SSH:
  ssh agent-admin@localhost -p ${SSH_PORT}

MSG

su - agent-admin