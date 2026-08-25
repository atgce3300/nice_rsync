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
- **Time-based scheduling** - Optional scheduler for specific time windows

## Quick Start

```bash
# Copy scripts
cp nice_rsync.sh /home/ubuntu/nice_rsync.sh
cp nice_rsync_scheduler.sh /home/ubuntu/nice_rsync_scheduler.sh
cp nice_rsync_stop.sh /home/ubuntu/nice_rsync_stop.sh
chmod +x /home/ubuntu/nice_rsync*.sh
```

## Scripts Included

| Script | Purpose |
|--------|---------|
| `nice_rsync.sh` | Main rsync backup script |
| `nice_rsync_scheduler.sh` | Time-based scheduler (runs during specific hours) |
| `nice_rsync_stop.sh` | Stop running rsync processes |

## Resource-Based Settings

Choose the settings that match your device capabilities:

| Device RAM | BWLIMIT | Use Case |
|------------|---------|----------|
| **512MB** | 500 KB/s | Very limited devices |
| **1GB** | 1000 KB/s | Low-end devices |
| **2GB** | 1500 KB/s | Normal devices |
| **4GB+** | 2000+ KB/s | Powerful devices |

### Recommended Settings

```bash
# For 512MB RAM
BWLIMIT="500"

# For 1GB RAM
BWLIMIT="1000"

# For 2GB RAM
BWLIMIT="1500"

# For 4GB+ RAM
BWLIMIT="2000"
```

## Source Drive Settings

### Recommended: Read-Only Source

For maximum safety, mount source as read-only:

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

#### When Read-Only is Not Practical

If source must be writable:
- Stop apps writing to drive before backup
- Run backup during idle periods

## Time-Based Scheduling

### Overview

The scheduler (`nice_rsync_scheduler.sh`) runs nice_rsync only during specific time windows.

### Configuration

Edit the scheduler script to set your allowed time windows:

```bash
# Example: Run only during 3-5 AM and 2-4 PM
ALLOWED_WINDOWS="03:00-05:00 14:00-16:00"

# Or single window:
# ALLOWED_WINDOWS="03:00-05:00"
```

### Time Window Format

- Format: `HH:MM-HH:MM` (24-hour)
- Multiple windows: Separate with spaces
- Overnight windows supported (e.g., `23:00-02:00`)

### Examples

| Schedule | Configuration |
|----------|--------------|
| 3-5 AM daily | `03:00-05:00` |
| 3-5 AM and 2-4 PM | `03:00-05:00 14:00-16:00` |
| Late night only | `23:00-02:00` |
| Business hours | `09:00-17:00` |

### Using the Scheduler

```bash
# Start scheduler
nohup /home/ubuntu/nice_rsync_scheduler.sh > /dev/null 2>&1 &

# Check if running
ps aux | grep scheduler

# View scheduler logs
tail -f /home/ubuntu/logs/scheduler-*.log
```

### Stopping the Scheduler

```bash
# Use the stop script
/home/ubuntu/nice_rsync_stop.sh

# Or manually
pkill -f "nice_rsync_scheduler"
pkill -f "nice_rsync.sh"
```

## Usage

### Direct Run

```bash
# Manual run
/home/ubuntu/nice_rsync.sh
```

### Run in TMUX

```bash
# Start in tmux
tmux new -d -s backup '/home/ubuntu/nice_rsync.sh'

# Watch progress
tmux attach -t backup
```

### Run via Cron

```bash
crontab -e

# Add this line (runs at 3 AM daily)
0 3 * * * /home/ubuntu/nice_rsync.sh
```

## Checking Status

```bash
# Check final status
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
| 11, 12, 23, 35, 255 | Retryable | Auto-retry |
| Other | Unexpected | Auto-retry |

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

If no passwordless sudo, modify `--rsync-path`:
```bash
# Original
--rsync-path="sudo nice -n 19 ionice -c 3 rsync"

# Alternative (no sudo)
--rsync-path="nice -n 19 ionice -c 3 rsync"
```

## Author

Created for reliable rsync backups on devices with limited resources.
