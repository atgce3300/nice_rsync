#!/usr/bin/env bash
# nice_rsync_stop.sh - Stop running nice_rsync and scheduler

LOG_DIR="/home/ubuntu/logs"

echo "Stopping nice_rsync processes..."

# Find and kill nice_rsync
pkill -f "nice_rsync.sh"
pkill -f "nice_rsync_scheduler"

# Also kill any running rsync processes from nice_rsync
pkill -f "rsync.*toshiba"

echo "Processes stopped."

# Check if any are still running
if pgrep -f "nice_rsync" > /dev/null 2>&1; then
    echo "Warning: Some processes may still be running."
    echo "Running processes:"
    ps aux | grep -E "nice_rsync|rsync.*toshiba" | grep -v grep
else
    echo "All nice_rsync processes stopped."
fi

# Update status
echo "STOPPED $(date '+%F %T')" > "$LOG_DIR/backup.status" 2>/dev/null
