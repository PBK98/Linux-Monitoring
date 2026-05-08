#!/usr/bin/env bash
set -u
SRC_DIR="/var/log/agent-app"
ARCHIVE_DIR="/var/log/monitor/agent-app/archive"
mkdir -p "$ARCHIVE_DIR"
find "$SRC_DIR" -type f -name '*.log' -mtime +7 -exec gzip -c {} \; -exec mv {} "$ARCHIVE_DIR" \;
find "$ARCHIVE_DIR" -type f -name '*.gz' -mtime +30 -delete
