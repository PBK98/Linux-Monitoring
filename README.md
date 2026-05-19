# Linux-Monitoring

## 시스템 관제 자동화 스크립트 개발

| 항목 | 내용 |
|---|---|
| 분야 | AI/SW 기초 |
| 구분 | Linux와 OS |
| 학습 시간 | 40시간 |
| 주제 | 시스템 관제 자동화 스크립트 개발 |

---

## 1. 미션 소개

서버 장애가 발생했을 때 로그가 없다면 원인 분석은 경험과 추측에 의존하게 됩니다. 실제 운영 환경에서는 이러한 상황이 복구 시간을 늘리고, 같은 장애가 반복되는 원인이 됩니다.

이번 미션에서는 리눅스 서버 운영 환경을 직접 구성하면서 다음 내용을 실습합니다.

- 다중 사용자 환경의 계정/그룹/권한 관리
- SSH 포트 변경과 Root 원격 접속 차단
- 방화벽을 통한 필요한 포트만 허용
- 환경 변수 기반 애플리케이션 실행 환경 구성
- 시스템 리소스 관제 자동화
- 로그 기록, 압축, 보존 정책 구성
- crontab을 통한 주기 실행 자동화

최종 목표는 단순한 리눅스 명령어 사용을 넘어, 실제 서버 운영자가 수행하는 보안 설정, 애플리케이션 실행, 관제, 로그 관리 자동화를 구현하는 것입니다.

---

## 2. 최종 결과물

제출해야 하는 산출물은 다음과 같습니다.

### 2.1 요구사항 수행 내역서

다음 항목을 포함합니다.

- 설정 및 명령어 기록
- SSH 포트 변경 내역
- Root 원격 접속 차단 확인
- 방화벽 규칙 확인
- 계정/그룹 생성 확인
- 디렉토리 구조 및 권한 확인
- 환경 변수 설정 확인
- 애플리케이션 Boot Sequence 성공 확인
- `monitor.sh` 실행 결과
- `monitor.log` 누적 기록 확인
- crontab 등록 및 자동 실행 확인

### 2.2 자동화 스크립트 소스코드

필수 제출 스크립트는 다음과 같습니다.

```text
monitor.sh
```

선택 또는 보너스 구현 스크립트는 다음과 같습니다.

```text
report.sh
log_archive.sh
setup_root.sh
setup_agent-admin.sh
```

---

## 3. 과제 목표

이 과제를 완료한 후 다음 내용을 설명할 수 있어야 합니다.

- SSH 포트 변경과 Root 원격 접속 차단이 기본 보안에 해당하는 이유
- UFW 또는 firewalld를 사용해 필요한 포트만 허용하는 방법
- 역할 기반 사용자/그룹 권한 분리 방식
- 공유 디렉토리와 보안 디렉토리를 분리하는 이유
- 환경 변수로 실행 환경을 고정하는 이유
- 쉘 스크립트로 프로세스, 포트, 리소스를 관제하는 방법
- crontab을 사용해 모니터링 작업을 자동 실행하는 방법
- 로그 보존 정책이 필요한 이유

---

## 4. 기능 요구 사항

### 4.1 기본 보안 및 네트워크 설정

#### SSH 설정

- SSH 접속 포트를 `20022`로 변경합니다.
- Root 원격 로그인을 차단합니다.

확인 예시:

```bash
grep '^Port\|^PermitRootLogin' /etc/ssh/sshd_config
ss -tulnp | grep ssh
```

정상 예시:

```text
Port 20022
PermitRootLogin no
```

#### 방화벽 설정

UFW 또는 firewalld 중 하나를 사용합니다.

허용 포트는 다음 두 개만 허용합니다.

```text
TCP 20022  # SSH
TCP 15034  # Agent Application
```

UFW 확인 예시:

```bash
sudo ufw status
```

firewalld 확인 예시:

```bash
sudo firewall-cmd --list-all
```

---

### 4.2 계정/그룹/권한 체계

#### 생성 계정

| 계정 | 역할 |
|---|---|
| `agent-admin` | 운영/관리, cron 실행자 |
| `agent-dev` | 개발/운영, `monitor.sh` 작성자 |
| `agent-test` | QA/테스트 |

#### 생성 그룹

| 그룹 | 포함 사용자 |
|---|---|
| `agent-common` | `agent-admin`, `agent-dev`, `agent-test` |
| `agent-core` | `agent-admin`, `agent-dev` |

확인 예시:

```bash
id agent-admin
id agent-dev
id agent-test

getent group agent-common
getent group agent-core
```

#### 디렉토리 구조

`AGENT_HOME` 기준 디렉토리 구조는 다음과 같습니다.

```text
/home/agent-admin/agent-app/
├── app/
│   └── agent-app
├── bin/
│   ├── monitor.sh
│   ├── report.sh
│   ├── log_archive.sh
│   └── setup_agent-admin.sh
├── api_keys/
│   └── t_secret.key
└── upload_files/
```

#### 접근 권한 정책

| 경로 | 그룹 | 권한 정책 |
|---|---|---|
| `$AGENT_HOME/upload_files` | `agent-common` | 읽기/쓰기 가능 |
| `$AGENT_HOME/api_keys` | `agent-core` | `agent-core`만 읽기/쓰기 가능 |
| `/var/log/agent-app` | `agent-core` | `agent-core`만 읽기/쓰기 가능 |

확인 예시:

```bash
ls -ld /home/agent-admin/agent-app
ls -ld /home/agent-admin/agent-app/upload_files
ls -ld /home/agent-admin/agent-app/api_keys
ls -ld /var/log/agent-app
```

ACL을 사용하는 경우:

```bash
getfacl /home/agent-admin/agent-app/upload_files
getfacl /home/agent-admin/agent-app/api_keys
```

---

### 4.3 애플리케이션 실행 환경 구성

#### 환경 변수

다음 환경 변수를 설정합니다.

| 변수 | 값 |
|---|---|
| `AGENT_HOME` | `/home/agent-admin/agent-app` |
| `AGENT_PORT` | `15034` |
| `AGENT_UPLOAD_DIR` | `$AGENT_HOME/upload_files` |
| `AGENT_KEY_PATH` | `$AGENT_HOME/api_keys/t_secret.key` |
| `AGENT_LOG_DIR` | `/var/log/agent-app` |

확인 예시:

```bash
source /etc/profile.d/agent-app.sh

echo "$AGENT_HOME"
echo "$AGENT_PORT"
echo "$AGENT_UPLOAD_DIR"
echo "$AGENT_KEY_PATH"
echo "$AGENT_LOG_DIR"
```

#### 키 파일

키 파일 경로:

```text
$AGENT_HOME/api_keys/t_secret.key
```

키 파일 내용:

```text
agent_api_key_test
```

#### 앱 실행 조건

- Root 사용자가 아닌 일반 계정으로 실행합니다.
- `agent-admin` 사용자로 실행합니다.
- Boot Sequence 5단계가 모두 `[OK]`여야 합니다.
- 마지막에 `Agent READY`가 출력되어야 합니다.
- `0.0.0.0:15034` 포트가 `LISTEN` 상태여야 합니다.

실행 예시:

```bash
su - agent-admin
source /etc/profile.d/agent-app.sh
cd /home/agent-admin/agent-app/app
./agent-app
```

백그라운드 실행 예시:

```bash
nohup ./agent-app > /tmp/agent_app.log 2>&1 &
```

확인 예시:

```bash
ps -ef | grep agent-app
ss -tulnp | grep 15034
tail -f /tmp/agent_app.log
```

---

### 4.4 시스템 관제 자동화 스크립트

#### `monitor.sh` 위치 및 권한

| 항목 | 값 |
|---|---|
| 경로 | `$AGENT_HOME/bin/monitor.sh` |
| 소유자 | `agent-dev` |
| 그룹 | `agent-core` |
| 권한 | `750` |
| cron 실행 계정 | `agent-admin` |

확인 예시:

```bash
ls -l /home/agent-admin/agent-app/bin/monitor.sh
```

정상 예시:

```text
-rwxr-x--- 1 agent-dev agent-core ... monitor.sh
```

#### Health Check

`monitor.sh`는 다음 항목을 확인합니다.

- `agent-app` 프로세스 실행 상태
- TCP `15034` 포트 LISTEN 상태

비정상일 경우 `exit 1`로 종료합니다.

#### 상태 점검

방화벽 상태를 확인합니다.

- UFW 또는 firewalld 활성화 상태 점검
- 비활성 상태일 경우 `[WARNING]` 출력
- 단, 스크립트는 종료하지 않음

#### 자원 수집

수집 항목은 다음과 같습니다.

| 항목 | 설명 |
|---|---|
| CPU | 프로세스 CPU 사용률 |
| MEM | 프로세스 메모리 사용률 |
| RSS | 실제 메모리 사용량(KB) |
| DISK_USED | Root partition 사용률 |

#### 임계값 경고

| 항목 | 조건 |
|---|---|
| CPU | `20%` 초과 시 경고 |
| MEM | `10%` 초과 시 경고 |
| DISK_USED | `80%` 초과 시 경고 |

#### 로그 기록

로그 파일:

```text
/var/log/agent-app/monitor.log
```

로그 포맷:

```text
[YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..% RSS:...KB
```

예시:

```text
[2026-05-18 21:20:01] PID:5288 CPU:0.00% MEM:0.0% DISK_USED:1% RSS:3336KB
```

---

### 4.5 로그 파일 용량 관리

`monitor.log`가 커질 경우 다음 조건을 만족해야 합니다.

- 최대 크기: `10MB`
- 최대 보관 개수: `10개`

예시: logrotate 사용

```text
/var/log/agent-app/monitor.log {
    size 10M
    rotate 10
    compress
    missingok
    notifempty
    copytruncate
}
```

설정 파일 위치:

```text
/etc/logrotate.d/agent-app
```

테스트 예시:

```bash
sudo logrotate -d /etc/logrotate.d/agent-app
sudo logrotate -f /etc/logrotate.d/agent-app
```

---

### 4.6 자동 실행 설정

`agent-admin` 계정의 crontab으로 `monitor.sh`를 매분 실행합니다.

등록 예시:

```bash
crontab -l 2>/dev/null
```

예상 항목:

```text
* * * * * . /etc/profile.d/agent-app.sh; /home/agent-admin/agent-app/bin/monitor.sh >> /var/log/agent-app/cron.log 2>&1
```

확인 예시:

```bash
crontab -u agent-admin -l
tail -f /var/log/agent-app/cron.log
tail -f /var/log/agent-app/monitor.log
```

---

## 5. 보너스 과제

### 5.1 `report.sh` 요약 리포트

`monitor.log`를 분석하여 다음 값을 출력합니다.

- CPU 평균/최대/최소
- MEM 평균/최대/최소
- DISK 평균/최대/최소
- 샘플 수

실행 예시:

```bash
/home/agent-admin/agent-app/bin/report.sh
```

출력 예시:

```text
====== STATISTICS REPORT ======
[CPU]
Average : 21.4%
Maximum : 25.3% at 2026-02-25 14:00:05
Minimum : 10.2% at 2026-02-25 13:58:05

[Memory]
Average : 6.1%
Maximum : 9.8% at 2026-02-25 14:00:05
Minimum : 3.2% at 2026-02-25 13:58:05

[Samples]
Data Points: 10 samples
```

---

### 5.2 시간 기반 로그 보존 정책

`log_archive.sh`는 다음 동작을 수행합니다.

- `/var/log/agent-app/*.log` 중 7일 이상 지난 파일 압축
- 압축 파일을 `/var/log/monitor/agent-app/archive/`로 이동
- 30일 이상 지난 `.gz` 파일 삭제
- 대상 파일이 없거나 권한이 부족한 경우 안전하게 종료 또는 경고 출력

실행 예시:

```bash
/home/agent-admin/agent-app/bin/log_archive.sh
```

확인 예시:

```bash
find /var/log/monitor/agent-app/archive -name "*.gz"
```

---

## 6. 개발 환경

권장 환경은 다음과 같습니다.

```text
Ubuntu 22.04 LTS 또는 동등 리눅스 환경
```

현재 실습 환경으로는 다음 구성을 사용할 수 있습니다.

```text
Ubuntu 24.04 VM
amd64/x86_64 architecture
```

> [!NOTE]
> 제공된 `agent-app` 바이너리가 Intel 계열(x86_64) 기준으로 빌드된 경우, ARM64 VM에서는 실행되지 않을 수 있습니다. 이 경우 amd64/x86_64 VM을 사용해야 합니다.

---

## 7. 제약 사항

- 자동화 스크립트는 Bash로 작성합니다.
- Python 등 다른 언어로 대체하지 않습니다.
- 필요한 경우에만 `sudo` 또는 root 권한을 사용합니다.
- 가능한 작업은 일반 계정(`agent-admin`)으로 수행합니다.
- 제공 애플리케이션은 실행 대상이며, 핵심 구현 대상은 관제/자동화 스크립트입니다.

---

## 8. 결과 예시

### 8.1 앱 Boot Sequence 출력 예시

```text
>>> Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
 ... Running as service user 'agent-admin' (uid=1001)
[2/5] Verifying Environment Variables     [OK]
 ... All required Envs correct
[3/5] Checking Required Files             [OK]
 ... Verified 'secret.key' with correct key string.
[4/5] Checking Port Availability          [OK]
 ... Port 15034 is available.
[5/5] Verifying Log Permission            [OK]
 ... Log directory is writable: /var/log/agent-app
--------------------------------------------------
All Boot Checks Passed!
Agent READY
```

### 8.2 `monitor.sh` 출력 예시

```text
====== SYSTEM MONITOR RESULT ======

[HEALTH CHECK]
Checking process 'agent-app'... [OK] (PID: 48291)
Checking port 15034... [OK]

[RESOURCE MONITORING]
CPU Usage : 25.3%
MEM Usage : 5.2%
DISK Used : 23%

[WARNING] CPU threshold exceeded (25.3% > 20%)

====== STATISTICS REPORT ======
[CPU]
Average : 21.4%
Maximum : 25.3% at 2026-02-25 14:00:05
Minimum : 10.2% at 2026-02-25 13:58:05

[Memory]
Average : 6.1%
Maximum : 9.8% at 2026-02-25 14:00:05
Minimum : 3.2% at 2026-02-25 13:58:05

[Samples]
Data Points: 10 samples

[INFO] Log appended: /var/log/agent-app/monitor.log
```

### 8.3 `monitor.log` 누적 예시

```text
[2026-02-25 13:58:01] PID:48291 CPU:10.2% MEM:3.2% DISK_USED:23% RSS:3336KB
[2026-02-25 13:59:01] PID:48291 CPU:18.7% MEM:5.0% DISK_USED:23% RSS:3340KB
[2026-02-25 14:00:01] PID:48291 CPU:25.3% MEM:9.8% DISK_USED:23% RSS:3400KB
```

---

## 9. 실행 순서 예시

### 9.1 root 단계

```bash
sudo ./setup_root.sh
```

### 9.2 agent-admin 단계

```bash
su - agent-admin
cd ~/Linux-Monitoring/UbuntuVM/scripts
./setup_agent-admin.sh
```

### 9.3 동작 확인

```bash
ps -ef | grep agent-app
ss -tulnp | grep 15034
/home/agent-admin/agent-app/bin/monitor.sh
/home/agent-admin/agent-app/bin/report.sh
crontab -l
tail -f /var/log/agent-app/monitor.log
```

---

## 10. 제출 체크리스트

- [ ] SSH 포트가 `20022`로 변경되어 있다.
- [ ] Root 원격 접속이 차단되어 있다.
- [ ] 방화벽에서 `20022/tcp`, `15034/tcp`만 허용되어 있다.
- [ ] `agent-admin`, `agent-dev`, `agent-test` 계정이 생성되어 있다.
- [ ] `agent-common`, `agent-core` 그룹이 생성되어 있다.
- [ ] 디렉토리 권한 정책이 요구사항에 맞게 적용되어 있다.
- [ ] 환경 변수가 `/etc/profile.d/agent-app.sh`에 설정되어 있다.
- [ ] `agent-app` Boot Sequence가 모두 `[OK]`이다.
- [ ] `agent-app`이 `15034` 포트에서 LISTEN 중이다.
- [ ] `monitor.sh`가 프로세스/포트/리소스를 점검한다.
- [ ] `/var/log/agent-app/monitor.log`에 로그가 누적된다.
- [ ] `agent-admin` crontab에 `monitor.sh` 매분 실행이 등록되어 있다.
- [ ] `monitor.log`가 최대 `10MB`, 최대 `10개` 파일로 관리된다.
