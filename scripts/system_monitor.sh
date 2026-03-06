#!/bin/bash
# =============================================================================
# System Monitor — Collects CPU, memory, disk metrics with alerting
# Author: Rahul Kumar
# Usage: ./system_monitor.sh [--alert]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/thresholds.conf"
LOG_DIR="${SCRIPT_DIR}/../logs"
LOG_FILE="${LOG_DIR}/system_$(date +%Y%m%d).log"
ALERT_MODE="${1:-}"

# Load thresholds
source "$CONFIG_FILE"

# --- Metric Collection ---

get_cpu_usage() {
    # Sample /proc/stat twice (like top/sar) to calculate real CPU usage
    local user1 nice1 system1 idle1 iowait1 irq1 softirq1
    local user2 nice2 system2 idle2 iowait2 irq2 softirq2

    read -r _ user1 nice1 system1 idle1 iowait1 irq1 softirq1 _ < /proc/stat
    local total1=$((user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1))
    local idle_total1=$((idle1 + iowait1))

    sleep 1

    read -r _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 _ < /proc/stat
    local total2=$((user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2))
    local idle_total2=$((idle2 + iowait2))

    local total_diff=$((total2 - total1))
    local idle_diff=$((idle_total2 - idle_total1))

    echo $(( (100 * (total_diff - idle_diff)) / total_diff ))
}

get_memory_usage() {
    # Reads /proc/meminfo — kernel's view of memory
    local total available
    total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    echo $(( (total - available) * 100 / total ))
}

get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}' | tr -d '%'
}

get_top_processes() {
    ps aux --sort=-%mem | head -6 | awk 'NR>1 {printf "  %-8s %-6s %-6s %s\n", $1, $3, $4, $11}'
}

# --- Reporting ---

timestamp=$(date '+%Y-%m-%d %H:%M:%S')
cpu=$(get_cpu_usage)
memory=$(get_memory_usage)
disk=$(get_disk_usage)
load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

report="
====================================================
  SYSTEM HEALTH REPORT — ${timestamp}
====================================================
  Hostname : $(hostname)
  Uptime   : $(uptime -p)
  Load Avg : ${load}
----------------------------------------------------
  CPU Usage    : ${cpu}%  $([ "$cpu" -gt "$CPU_THRESHOLD" ] && echo '[!!! ALERT]' || echo '[OK]')
  Memory Usage : ${memory}%  $([ "$memory" -gt "$MEMORY_THRESHOLD" ] && echo '[!!! ALERT]' || echo '[OK]')
  Disk Usage   : ${disk}%  $([ "$disk" -gt "$DISK_THRESHOLD" ] && echo '[!!! ALERT]' || echo '[OK]')
----------------------------------------------------
  Top Processes by Memory:
$(get_top_processes)
===================================================="

echo "$report"
echo "$report" >> "$LOG_FILE"

# --- Alerting ---

if [[ "$ALERT_MODE" == "--alert" ]]; then
    alerts=""
    [ "$cpu" -gt "$CPU_THRESHOLD" ] && alerts+="CPU at ${cpu}% (threshold: ${CPU_THRESHOLD}%)\n"
    [ "$memory" -gt "$MEMORY_THRESHOLD" ] && alerts+="Memory at ${memory}% (threshold: ${MEMORY_THRESHOLD}%)\n"
    [ "$disk" -gt "$DISK_THRESHOLD" ] && alerts+="Disk at ${disk}% (threshold: ${DISK_THRESHOLD}%)\n"

    if [ -n "$alerts" ]; then
        echo -e "\n🚨 ALERTS TRIGGERED:\n${alerts}" | tee -a "$LOG_FILE"
        # In production, you'd send this to Slack/PagerDuty:
        # curl -X POST -H 'Content-type: application/json' \
        #   --data "{\"text\":\"Server Alert: ${alerts}\"}" \
        #   "$SLACK_WEBHOOK_URL"
    fi
fi
