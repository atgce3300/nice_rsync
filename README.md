# nice_rsync

A robust rsync wrapper script designed for reliable file transfers, especially for devices with limited resources.

## Overview

nice_rsync is a wrapper script that provides:
- **Pre-flight checks** - Verify source mounted, remote reachable, disk space
- **Resumable transfers** - Uses `--partial` for interrupted transfer recovery
- **Auto-retries** - Retries on transient failures (network, IO, protocol errors)
- **Safe to re-run** - Uses `flock` lock to prevent parallel instances
- **Resource friendly** - Optimized for limited resource devices
- **Comprehensive logging** - Timestamped logs + status file

## How It Works

```
Pre-flight gates → Check source → Check remote → Check space → RSync with retry → Status
```

### Key Features

| Feature | Purpose |
|---------|---------|
| Pre-flight gates | Local drive mounted? Remote reachable? Disk space? |
| `--partial` | Resumable - interrupted transfers continue on retry |
| Retry loop | 5 retries with 60s delay on transient failures |
| flock lock | Prevents parallel runs from corrupting data |
| Status file | One command to check success: `cat backup.status` |
| Bandwidth limit | Prevents saturating network |
| Nice/Ionice | Low CPU/I/O priority for limited devices |

## Installation

```bash
# Copy script
cp nice_rsync.sh /home/ubuntu/nice_rsync.sh
chmod +x /home/ubuntu/nice_rsync.sh
```

## Configuration

Edit these variables at the top of the script:

```bash
SRC="/media/toshiba2025/"           # Source directory
DST_HOST="ubuntu@XX.X.X.X"         # Remote host
DST_PATH="/media/toshiba2025/"     # Remote path
SSH_KEY="/home/ubuntu/.ssh/wg_rsync_key"  # SSH key
BWLIMIT="2000"                      # KB/s - bandwidth limit
MAX_RETRIES=5                       # Number of retry attempts
RETRY_DELAY=60                       # Seconds between retries
```

## Resource-Based Settings

Choose the settings that match your device capabilities:

| Device RAM | BWLIMIT | niceness | ionice | Use Case |
|------------|---------|----------|--------|----------|
| **512MB** | 500 KB/s | nice -n 19 | ionice -c 3 | Very limited devices |
| **1GB** | 1000 KB/s | nice -n 19 | ionice -c 3 | Low-end devices |
| **2GB** | 1500 KB/s | nice -n 19 | ionice -c 3 | Normal devices |
| **4GB+** | 2000+ KB/s | nice -n 19 | ionice -c 3 | Powerful devices |

### Recommended Settings

#### For 512MB RAM (Very Limited)
```bash
BWLIMIT="500"
```

#### For 1GB RAM (Low-End)
```bash
BWLIMIT="1000"
```

#### For 2GB RAM (Normal)
```bash
BWLIMIT="1500"
```

#### For 4GB+ RAM (Powerful)
```bash
BWLIMIT="2000"
```

## Source Drive Settings

### Recommended: Read-Only Source

For maximum safety and data integrity, **mount the source drive as read-only** when possible:

```bash
# Mount as read-only
mount -o ro /dev/sdX /media/toshiba2025
```

#### Benefits of Read-Only Source

| Benefit | Description |
|---------|-------------|
| **Consistent data** | Files don't change during transfer |
| **Point-in-time snapshot** | Exact copy at backup time |
| **Safety** | Protects against accidental deletion |
| **Ransomware protection** | Can't encrypt read-only drive |

#### When Read-Only is Not Practical

If you must keep the source writable:
- Stop applications writing to the drive before backup
- Run backup during idle periods
- Accept slightly higher risk of partial copies

## Usage

### Manual Run

```bash
# Test first run
/home/ubuntu/nice_rsync.sh
```

### Run in TMUX (Recommended)

```bash
# Start backup in tmux
tmux new -d -s backup '/home/ubuntu/nice_rsync.sh'

# Watch progress
tmux attach -t backup
```

### Run via Cron

```bash
# Edit crontab
crontab -e

# Add this line (runs at 3 AM daily)
0 3 * * * /home/ubuntu/nice_rsync.sh
```

**Note:** The flock lock makes it safe to run via cron - if a previous run is still active, the new instance will exit.

## Checking Status

```bash
# Check final status (one command)
cat /home/ubuntu/logs/backup.status

# View logs
ls -la /home/ubuntu/logs/

# Watch log in real-time
tail -f /home/ubuntu/logs/rsync-*.log
```

## Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | ✅ Done |
| 24 | Files vanished | ✅ Normal - treated as success |
| 11, 12, 23, 35, 255 | Retryable error | Auto-retry |
| Other | Unexpected | Auto-retry |

## Troubleshooting

### Script won't start
- Check if another instance is running: `ps aux | grep nice_rsync`
- Check lock file: `ls -la /tmp/toshiba_backup.lock`

### Remote not reachable
- Verify SSH key is installed on remote
- Check WireGuard/tunnel is active
- Test manually: `ssh -i $SSH_KEY $DST_HOST true`

### No disk space on remote
- Check remote: `df -h`
- Free up space or use different destination

### Transfer too slow
- Adjust `BWLIMIT` for your network speed
- Lower values for limited devices

## Requirements

- rsync
- ssh
- flock (util-linux)
- nice (coreutils)
- ionice (util-linux)

```bash
# Install on Debian/Ubuntu
sudo apt install rsync util-linux coreutils
```

## Remote Server Setup

On the remote server, ensure:

1. SSH key is authorized
2. rsync is installed
3. User has sudo access (for nice/ionice)

If user doesn't have passwordless sudo, modify `--rsync-path`:
```bash
# Original (requires sudo)
--rsync-path="sudo nice -n 19 ionice -c 3 rsync"

# Alternative (no sudo needed)
--rsync-path="nice -n 19 ionice -c 3 rsync"
```

## Disclaimer

This script handles software-related failures but cannot fix hardware issues. If transfers keep failing, check:
- USB power/connection quality
- RAM/health status (`memtester`, `dmesg`)
- Network stability
- Disk SMART status

## Author

Created for reliable rsync backups on devices with limited resources.
