#!/usr/bin/env python3

import os
import sys
import pwd
import socket
from pathlib import Path

print("Starting Agent Boot Sequence...")

REQUIRED_GROUP = "agent-admin"

REQUIRED_ENVS = {
    'AGENT_HOME': '/home/agent-admin/agent-app',
    'AGENT_LOG_DIR': '/var/log/agent-app',
}

# =========================
# [1/5] User Check
# =========================

REQUIRED_USER = "agent-admin"

current_user = pwd.getpwuid(os.getuid()).pw_name

print("[1/5] Checking User Account", end=' ')

if current_user != REQUIRED_USER:
    print("[ERROR]")
    print(f"... Current User : {current_user}")
    print(f"... Required User : {REQUIRED_USER}")
    sys.exit(1)

print("[OK]")
print(f"... Running as service user '{REQUIRED_USER}'")

# =========================
# [2/5] Environment Variables
# =========================

print("[2/5] Verifying Environment Variables", end=' ')

for key, value in REQUIRED_ENVS.items():
    if os.environ.get(key) != value:
        print("[ERROR]")
        print(f"... Invalid ENV : {key}")
        sys.exit(1)

print("[OK]")
print("... All required Envs correct")

# =========================
# [3/5] Key File Check
# =========================

print("[3/5] Checking Required Files", end=' ')

key_file = Path(os.environ['AGENT_HOME']) / 'api_keys/t_secret.key'

if not key_file.exists():
    print("[ERROR]")
    print("... Key file missing.")
    sys.exit(1)

with open(key_file) as f:
    key = f.read().strip()

if key != 'agent_api_key_test':
    print("[ERROR]")
    print("... Invalid key.")
    sys.exit(1)

print("[OK]")
print("... Verified key file with correct key string.")

# =========================
# [4/5] Port Check
# =========================

print("[4/5] Starting Agent Port", end=' ')

PORT = int(os.environ.get("AGENT_PORT", "15034"))

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

try:
    sock.bind(("0.0.0.0", PORT))
    sock.listen(5)
except OSError:
    print("[ERROR]")
    print(f"... Port {PORT} already in use.")
    sys.exit(1)

print("[OK]")
print(f"... Listening on port {PORT}")

# =========================
# [5/5] READY
# =========================

print("[5/5] Agent Status [READY]")

while True:
    conn, addr = sock.accept()
    conn.sendall(b"Agent READY\n")
    conn.close()