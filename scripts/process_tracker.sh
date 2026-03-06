#!/bin/bash
# Logs top resource-consuming processes over time
# Useful for finding memory leaks and CPU hogs
set -euo pipefail

LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../logs" && pwd)"
LOG_FILE="${LOG_DIR}/processes_$(date +%Y%m%d).log"

echo "=== Process Snapshot: $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "--- Top 10 by CPU ---" >> "$LOG_FILE"
ps aux --sort=-%cpu | head -11 >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "--- Top 10 by Memory ---" >> "$LOG_FILE"
ps aux --sort=-%mem | head -11 >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "--- Zombie Processes ---" >> "$LOG_FILE"
zombies=$(ps aux | awk '$8 ~ /Z/ {print}')
if [ -n "$zombies" ]; then
    echo "$zombies" >> "$LOG_FILE"
else
    echo "None found." >> "$LOG_FILE"
fi

echo "Snapshot saved to ${LOG_FILE}"
