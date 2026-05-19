실행 순서

1. root 계정 passwd 설정
```bash
passwd root
```
2. root 계정으로 전환
```bash
su -
```
3. git repository 연결 및 setup_root.sh 실행
```bash
apt update && sudo apt install -y git && sudo git clone https://github.com/PBK98/Linux-Monitoring.git &&  cd Linux-Monitoring/UbuntuVM/scripts/ && bash setup_root.sh
```
4. setup_root.sh 에서 자동 agent-admin 계정으로 전환 후 setup_agent-admin.sh 실행
```bash
cd /home/agent-admin/agent-app/bin/ && bash setup_agent-admin.sh 
```
5. monitor.log 확인
```bash
tail -f /var/log/agent-app/monitor.log
```