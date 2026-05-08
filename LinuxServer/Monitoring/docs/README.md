# Linux OS 시스템 관제 자동화 스크립트 과제

## 실행 순서

```bash
unzip linux_os_assignment.zip
cd linux_os_assignment/scripts
chmod +x *.sh
./setup.sh
sudo -iu agent-admin
source /etc/profile.d/agent-app.sh
python3 $AGENT_HOME/agent_app.py
```

다른 터미널에서 확인:

```bash
sudo -iu agent-admin
source /etc/profile.d/agent-app.sh
$AGENT_HOME/bin/monitor.sh
cat /var/log/agent-app/monitor.log
```

## 포함 파일

- `app/agent_app.py`: 부팅 체크 및 15034 포트 LISTEN 테스트 앱
- `scripts/setup.sh`: 사용자/그룹/디렉터리/권한/방화벽/cron 설정
- `scripts/monitor.sh`: 프로세스, 포트, CPU, MEM, DISK 관제 및 로그 기록
- `scripts/report.sh`: monitor.log 기반 평균/최대/최소 통계 출력
- `scripts/log_archive.sh`: 7일 초과 로그 압축/이동, 30일 초과 압축 로그 삭제

## 주요 요구사항 반영

- SSH 포트: 20022 허용
- APP 포트: 15034 허용
- 사용자: agent-admin, agent-dev, agent-test
- 그룹: agent-common, agent-core
- upload_files: agent-common R/W
- api_keys, /var/log/agent-app: agent-core R/W
- monitor.sh 권한: 750
- cron: agent-admin 기준 1분마다 monitor.sh 실행
