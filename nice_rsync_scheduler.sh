#!/usr/bin/env bash
# nice_rsync_scheduler.sh - Time-based scheduler for nice_rsync
# Runs nice_rsync only during allowed time windows

# === Configuration ===
# Time window format: HH:MM-HH:MM (24-hour format)
# Multiple windows can be defined, separated by space

ALLOWED_WINDOWS="03:00-05:00 14:00-16:00"  # Example: 3-5 AM and 2-4 PM
# Or set to a single window:
# ALLOWED_WINDOWS="03:00-05:00"

# Path to nice_rsync script
RSYNC_SCRIPT="/home/ubuntu/nice_rsync.sh"

# Check interval (seconds)
CHECK_INTERVAL=300  # Check every 5 minutes

# Log file
LOG_DIR="/home/ubuntu/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/scheduler-$(date +%Y%m%d).log"

# === Functions ===

log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

# Check if current time is within allowed window
is_within_window() {
    local current_time=$(date +%H:%M)
    
    for window in $ALLOWED_WINDOWS; do
        local start_time="${window%-*}"
        local end_time="${window#*-}"
        
        # Handle overnight windows (e.g., 23:00-02:00)
        if [[ "$start_time" > "$end_time" ]]; then
            # Overnight window
            if [[ "$current_time" >= "$start_time" ]] || [[ "$current_time" < "$end_time" ]]; then
                return 0
            fi
        else
            # Normal window
            if [[ "$current_time" >= "$start_time" ]] && [[ "$current_time" < "$end_time" ]]; then
                return 0
            fi
        fi
    done
    return 1
}

# Check if rsync is currently running
is_rsync_running() {
    pgrep -f "nice_rsync" > /dev/null 2>&1
}

# Stop running rsync gracefully
stop_rsync() {
    log "Stopping rsync process..."
    pkill -f "nice_rsync.sh"
    
    # Wait for process to stop (max 30 seconds)
    local count=0
    while is_rsync_running && [ $count -lt 30 ]; do
        sleep 1
        count=$((count + 1))
    done
    
    if is_rsync_running; then
        log "Force killing rsync..."
        pkill -9 -f "nice_rsync.sh"
    fi
    
    log "Rsync stopped."
}

# Start rsync
start_rsync() {
    if is_rsync_running; then
        log "Rsync already running, skipping..."
        return
    fi
    
    log "Starting rsync..."
    nohup "$RSYNC_SCRIPT" > "$LOG_DIR/rsync-nohup.log" 2>&1 &
    log "Rsync started in background."
}

# === Main Loop ===
log "=== Scheduler started ==="
log "Allowed windows: $ALLOWED_WINDOWS"

while true; do
    if is_within_window; then
        log "Within allowed time window."
        start_rsync
    else
        log "Outside allowed time window."
        if is_rsync_running; then
            stop_rsync
        fi
    fi
    
    sleep "$CHECK_INTERVAL"
done
