#!/usr/bin/env bash
# Robust rsync backup: /media/toshiba2025 -> ubuntu@XX.X.X.X:/media/toshiba2025
# - resumable (--partial), auto-retries, safe to re-run (flock + resume)
# - logs every attempt with timestamps

set -u

SRC="/media/toshiba2025/"
DST_HOST="ubuntu@XX.X.X.X"
DST_PATH="/media/toshiba2025/"
SSH_KEY="/home/ubuntu/.ssh/wg_rsync_key"
BWLIMIT="2000"            # KB/s — tune to your link
LOG_DIR="/home/ubuntu/logs"
LOCK_FILE="/tmp/toshiba_backup.lock"
STATUS_FILE="$LOG_DIR/backup.status"
MAX_RETRIES=5
RETRY_DELAY=60            # seconds between attempts

mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/rsync-$(date +%Y%m%d-%H%M%S).log"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
die()  { log "FATAL: $*"; echo "FAILED $(date '+%F %T')" > "$STATUS_FILE"; exit 1; }

# --- lock: never run two instances at once ---
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log "Another backup instance is already running. Exiting."
    exit 1
fi

log "=== Backup start ==="

# --- pre-flight: local source mounted? ---
[ -d "$SRC" ] || die "Source $SRC not mounted or missing."

# --- pre-flight: remote reachable (BatchMode = no password prompt hangs) ---
if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o BatchMode=yes "$DST_HOST" true 2>/dev/null; then
    die "Remote $DST_HOST not reachable over WireGuard."
fi

# --- pre-flight: remote disk space (KB; warn if under ~1 GB) ---
REMOTE_FREE=$(ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o BatchMode=yes "$DST_HOST" \
    "df -P $DST_PATH | awk 'NR==2{print \$4}'" 2>/dev/null)
[ -n "$REMOTE_FREE" ] || die "Could not query remote disk space."
[ "$REMOTE_FREE" -ge 1048576 ] || log "WARNING: remote free space only $((REMOTE_FREE/1024)) MB"

RSYNC_OPTS=(
  -a
  --partial
  --timeout=600
  --contimeout=30
  --bwlimit="$BWLIMIT"
  --rsync-path="sudo nice -n 19 ionice -c 3 rsync"
  --stats
  -e "ssh -i $SSH_KEY -o ServerAliveInterval=30 -o ServerAliveCountMax=4 -o ConnectTimeout=15"
)
attempt=0
rc=1
while [ "$attempt" -lt "$MAX_RETRIES" ]; do
    attempt=$((attempt + 1))
    log "Attempt $attempt/$MAX_RETRIES"

    sudo nice -n 19 ionice -c 3 \
        rsync "${RSYNC_OPTS[@]}" "$SRC" "$DST_HOST:$DST_PATH" >> "$LOG" 2>&1
    rc=$?

    case "$rc" in
        0)
            log "SUCCESS (exit 0)"
            echo "OK $(date '+%F %T')" > "$STATUS_FILE"
            exit 0
            ;;
        24)
            # files vanished mid-transfer — normal, treat as success
            log "Exit 24 (files vanished) — treated as success."
            echo "OK $(date '+%F %T')" > "$STATUS_FILE"
            exit 0
            ;;
        11|12|23|35|255)
            log "Retryable error (exit $rc) — retrying in ${RETRY_DELAY}s..."
            ;;
        *)
            log "Unexpected exit code $rc — retrying anyway."
            ;;
    esac
    [ "$attempt" -lt "$MAX_RETRIES" ] && sleep "$RETRY_DELAY"
done

log "FAILED after $MAX_RETRIES attempts. Log: $LOG"
echo "FAILED $(date '+%F %T')" > "$STATUS_FILE"
exit 1
