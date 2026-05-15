#!/usr/bin/env bash
set -euo pipefail
AGENT_HOME=/home/agent-admin/agent-app

sudo groupadd -f agent-common
sudo groupadd -f agent-core
for u in agent-admin agent-dev agent-test; do
  id "$u" >/dev/null 2>&1 || sudo useradd -m -s /bin/bash "$u"
done
sudo usermod -aG agent-common,agent-core agent-admin
sudo usermod -aG agent-common,agent-core agent-dev
sudo usermod -aG agent-common agent-test

sudo mkdir -p "$AGENT_HOME"/{upload_files,api_keys,bin} /var/log/agent-app /var/log/monitor/agent-app/archive
sudo cp ../app/agent_app.py "$AGENT_HOME/agent_app.py"
sudo cp monitor.sh report.sh log_archive.sh "$AGENT_HOME/bin/"
sudo chmod +x "$AGENT_HOME/agent_app.py" "$AGENT_HOME/bin/"*.sh

echo 'agent_api_key_test' | sudo tee "$AGENT_HOME/api_keys/t_secret.key" >/dev/null
sudo chown -R agent-admin:agent-common "$AGENT_HOME"
sudo chgrp agent-common "$AGENT_HOME/upload_files"
sudo chmod 770 "$AGENT_HOME/upload_files"
sudo chgrp -R agent-core "$AGENT_HOME/api_keys" /var/log/agent-app
sudo chmod 770 "$AGENT_HOME/api_keys" /var/log/agent-app
sudo chmod 660 "$AGENT_HOME/api_keys/t_secret.key"
sudo chown agent-dev:agent-core "$AGENT_HOME/bin/monitor.sh" "$AGENT_HOME/bin/report.sh"
sudo chmod 750 "$AGENT_HOME/bin/monitor.sh" "$AGENT_HOME/bin/report.sh"

sudo tee /etc/profile.d/agent-app.sh >/dev/null <<EOF
export AGENT_HOME=$AGENT_HOME
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys/t_secret.key
export AGENT_LOG_DIR=/var/log/agent-app
EOF

if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow 20022/tcp || true
  sudo ufw allow 15034/tcp || true
elif command -v firewall-cmd >/dev/null 2>&1; then
  sudo firewall-cmd --permanent --add-port=20022/tcp || true
  sudo firewall-cmd --permanent --add-port=15034/tcp || true
  sudo firewall-cmd --reload || true
fi

( sudo crontab -u agent-admin -l 2>/dev/null | grep -v 'monitor.sh'; echo '* * * * * . /etc/profile.d/agent-app.sh; /home/agent-admin/agent-app/bin/monitor.sh >> /var/log/agent-app/cron.log 2>&1' ) | sudo crontab -u agent-admin -
( sudo crontab -u agent-admin -l 2>/dev/null | grep -v 'log_archive.sh'; echo '0 3 * * * /home/agent-admin/agent-app/bin/log_archive.sh >> /var/log/agent-app/archive.log 2>&1' ) | sudo crontab -u agent-admin -

echo 'Setup complete. Run: sudo -iu agent-admin bash -lc "source /etc/profile.d/agent-app.sh && python3 $AGENT_HOME/agent_app.py"'
