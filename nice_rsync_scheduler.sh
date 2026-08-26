#!/usr/bin/env bash
# nice_rsync_scheduler.sh - Time-based scheduler for nice_rsync
# Runs nice_rsync only during allowed time windows
# Includes OOM protection to stop rsync if memory is too low

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

# OOM Protection Settings
# Free memory threshold (MB) - stop rsync if free memory below this
OOM_THRESHOLD_MB=100

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

# Get available memory in MB
get_available_memory_mb() {
    # Available memory in kB, convert to MB
    local avail_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    echo $((avail_kb / 1024))
}

# Check memory and stop rsync if too low
check_memory_and_protect() {
    local available_mb=$(get_available_memory_mb)
    
    log "Available memory: ${available_mb} MB (threshold: ${OOM_THRESHOLD_MB} MB)"
    
    if [ "$available_mb" -lt "$OOM_THRESHOLD_MB" ]; then
        log "WARNING: Low memory detected! Available: ${available_mb} MB"
        
        if is_rsync_running; then
            log "Stopping rsync due to low memory (OOM protection)"
            stop_rsync
            log "Rsync stopped due to low memory."
            return 1
        fi
    fi
    
    return 0
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
    # Check memory before starting
    if ! check_memory_and_protect; then
        log "Cannot start rsync - memory too low."
        return
    fi
    
    if is_rsync_running; then
        log "Rsync already running, skipping..."
        return
    fi
    
    log "Starting rsync..."
    nohup "$RSYNC_SCRIPT" > "$LOG_DIR/rsync-nohup.log" 2>&1 &
    log "Rsync started in background."
}

# === Main ===
LOG_DIR="/home/ubuntu/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/scheduler-$(date +%Y%m%d).log"

log "=== Scheduler started ==="
log "Allowed windows: $ALLOWED_WINDOWS"
log "OOM threshold: ${OOM_THRESHOLD_MB} MB"

while true; do
    # Always check memory - even outside time window
    check_memory_and_protect
    
    if is_within_window; then
        log "Within allowed time window."
        
        # Check memory again before starting
        if check_memory_and_protect; then
            start_rsync
        else
            log "Skipping rsync start - memory too low."
        fi
    else
        log "Outside allowed time window."
        if is_rsync_running; then
            stop_rsync
        fi
    fi
    
    sleep "$CHECK_INTERVAL"
done
