#!/usr/bin/env python3

import os
import sys
import grp
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
# [1/5] Group Check
# =========================

current_user = pwd.getpwuid(os.getuid()).pw_name

group_names = [
    grp.getgrgid(gid).gr_name
    for gid in os.getgroups()
]

print("[1/5] Checking User Group", end=' ')

if REQUIRED_GROUP not in group_names:
    print("[ERROR]")
    print(f"... Current User : {current_user}")
    print(f"... Required Group : {REQUIRED_GROUP}")
    print(f"... Current Groups : {group_names}")
    sys.exit(1)

print("[OK]")
print(f"... User '{current_user}' belongs to '{REQUIRED_GROUP}'")

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

print("[4/5] Checking Port Availability", end=' ')

PORT = int(os.environ.get("AGENT_PORT", "15034"))

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

try:
    sock.bind(("0.0.0.0", PORT))
except OSError:
    print("[ERROR]")
    print(f"... Port {PORT} already in use.")
    sys.exit(1)

sock.close()

print("[OK]")
print(f"... Port {PORT} available.")

# =========================
# [5/5] READY
# =========================

print("[5/5] Agent Status [READY]")

while True:
    pass