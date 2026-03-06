#!/bin/bash
# Alerts when any mounted filesystem exceeds threshold
set -euo pipefail

THRESHOLD="${1:-90}"

echo "Checking disk usage (threshold: ${THRESHOLD}%)..."
echo "---------------------------------------------------"

alert_triggered=false

while IFS= read -r line; do
    usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
    mount=$(echo "$line" | awk '{print $6}')
    filesystem=$(echo "$line" | awk '{print $1}')

    if [ "$usage" -gt "$THRESHOLD" ]; then
        echo "🚨 ALERT: ${mount} is at ${usage}% (${filesystem})"
        alert_triggered=true
    else
        echo "   OK: ${mount} at ${usage}%"
    fi
done < <(df -h --type=ext4 --type=xfs --type=btrfs 2>/dev/null | tail -n +2)

if [ "$alert_triggered" = false ]; then
    echo "✅ All filesystems within limits."
fi
