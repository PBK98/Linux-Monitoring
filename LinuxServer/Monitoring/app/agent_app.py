#!/usr/bin/env python3
import os, socket, sys, time

def check_env():
    required = {
        'AGENT_HOME': '/home/agent-admin/agent-app',
        'AGENT_PORT': '15034',
        'AGENT_UPLOAD_DIR': os.path.join(os.environ.get('AGENT_HOME',''), 'upload_files'),
        'AGENT_KEY_PATH': os.path.join(os.environ.get('AGENT_HOME',''), 'api_keys/t_secret.key'),
        'AGENT_LOG_DIR': '/var/log/agent-app',
    }
    for k, expected in required.items():
        actual = os.environ.get(k)
        if actual != expected:
            print(f"[ERROR] {k} invalid: {actual!r}, expected: {expected!r}")
            return False
    return True

def boot_check():
    print("Starting Agent Boot Sequence...")
    print("[1/5] Checking User Account", end=' ')
    if os.environ.get('USER') != 'agent-admin':
        print('[ERROR]')
        return False
    print('[OK]')
    print("... Running as service user 'agent-admin'")

    print("[2/5] Verifying Environment Variables", end=' ')
    if not check_env():
        return False
    print('[OK]')
    print('... All required Envs correct')

    print("[3/5] Checking Required Files", end=' ')
    key_path = os.environ['AGENT_KEY_PATH']
    try:
        with open(key_path) as f:
            key = f.read().strip()
        if key != 'agent_api_key_test':
            print('[ERROR]')
            return False
    except Exception:
        print('[ERROR]')
        return False
    print('[OK]')
    print('... Verified key file with correct key string.')

    port = int(os.environ['AGENT_PORT'])
    print("[4/5] Checking Port Availability", end=' ')
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.bind(('0.0.0.0', port))
        s.close()
    except OSError:
        print('[ERROR]')
        return False
    print('[OK]')
    print(f'... Port {port} is available.')

    print("[5/5] Verifying Log Permission", end=' ')
    log_dir = os.environ['AGENT_LOG_DIR']
    if not os.access(log_dir, os.W_OK):
        print('[ERROR]')
        return False
    print('[OK]')
    print(f'... Log directory is writable: {log_dir}')
    print('-' * 60)
    print('All Boot Checks Passed!')
    print('Agent READY')
    return True

def main():
    if not boot_check():
        sys.exit(1)
    port = int(os.environ['AGENT_PORT'])
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('0.0.0.0', port))
    s.listen(5)
    try:
        while True:
            conn, addr = s.accept()
            conn.sendall(b'Agent READY\n')
            conn.close()
    except KeyboardInterrupt:
        pass

if __name__ == '__main__':
    main()
