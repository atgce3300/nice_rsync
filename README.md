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
- **OOM protection** - Automatically stops if memory is too low

## Scripts Comparison

| Feature | nice_rsync.sh | nice_rsync_scheduler.sh | nice_rsync_stop.sh |
|---------|---------------|------------------------|-------------------|
| **Purpose** | Main backup script | Time-based scheduler | Emergency stop |
| **Runs rsync** | ✅ Yes (manual) | ✅ Yes (automatic) | ❌ No |
| **Time windows** | ❌ No | ✅ Yes | ❌ No |
| **OOM protection** | ❌ No | ✅ Yes | ❌ No |
| **Manual control** | ✅ Full | ✅ Partial | ✅ Full |

### When to Use Each

| Scenario | Script |
|----------|--------|
| Run backup manually at any time | `nice_rsync.sh` |
| Run backup only during specific hours | `nice_rsync_scheduler.sh` |
| Emergency stop - immediately halt all | `nice_rsync_stop.sh` |

## Quick Start

```bash
# Copy all scripts
cp nice_rsync.sh /home/ubuntu/nice_rsync.sh
cp nice_rsync_scheduler.sh /home/ubuntu/nice_rsync_scheduler.sh
cp nice_rsync_stop.sh /home/ubuntu/nice_rsync_stop.sh
chmod +x /home/ubuntu/nice_rsync*.sh
```

## Resource-Based Settings

Choose the settings that match your device capabilities:

| Device RAM | BWLIMIT | Use Case |
|------------|---------|----------|
| **512MB** | 500 KB/s | Very limited devices |
| **1GB** | 1000 KB/s | Low-end devices |
| **2GB** | 1500 KB/s | Normal devices |
| **4GB+** | 2000+ KB/s | Powerful devices |

## Source Drive Settings

### Recommended: Read-Only Source

For maximum safety, mount source as read-only:

```bash
# Mount as read-only
mount -o ro /dev/sdX /media/toshiba2025
```

## Time-Based Scheduling

### Overview

The scheduler (`nice_rsync_scheduler.sh`) runs nice_rsync only during specific time windows. It also includes **OOM protection** to automatically stop rsync if memory is too low.

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

### OOM Protection

The scheduler includes automatic memory protection:

| Setting | Default | Description |
|---------|---------|-------------|
| `OOM_THRESHOLD_MB` | 100 MB | Stop rsync if free memory below this |

If available memory drops below the threshold, the scheduler will automatically stop the running rsync process to prevent system crash.

### Using the Scheduler

```bash
# Start scheduler (runs in background)
nohup /home/ubuntu/nice_rsync_scheduler.sh > /dev/null 2>&1 &

# Check if running
ps aux | grep scheduler

# View scheduler logs
tail -f /home/ubuntu/logs/scheduler-*.log
```

## How to Run the Scheduler

### Step 1: Configure Time Windows

Edit `nice_rsync_scheduler.sh`:

```bash
ALLOWED_WINDOWS="03:00-05:00 14:00-16:00"
```

### Step 2: Start the Scheduler

```bash
# Make executable
chmod +x nice_rsync_scheduler.sh

# Start (runs forever in background)
nohup ./nice_rsync_scheduler.sh > scheduler.log 2>&1 &
```

### Step 3: Monitor

```bash
# Check if running
ps aux | grep scheduler

# View logs
tail -f /home/ubuntu/logs/scheduler-YYYYMMDD.log
```

## How to Stop the Scheduler

### Method 1: Use Stop Script (Recommended)

```bash
# Stop both scheduler AND any running rsync
./nice_rsync_stop.sh
```

### Method 2: Manual Stop

```bash
# Kill scheduler
pkill -f "nice_rsync_scheduler"

# Kill rsync
pkill -f "nice_rsync.sh"
```

### Method 3: Graceful Stop (via Scheduler)

The scheduler automatically stops rsync when outside the time window. Wait for the window to end, or:

```bash
# Change ALLOWED_WINDOWS to empty, then restart scheduler
ALLOWED_WINDOWS=""
# Then: pkill -f scheduler; nohup ./scheduler.sh &
```

## Running Both Scheduler and Stop Script

### Workflow

1. **Start Scheduler** - Runs automatically during allowed times
2. **Monitor** - Check logs for status
3. **Emergency Stop** - Use stop script if needed

```bash
# Start scheduler
nohup ./nice_rsync_scheduler.sh > /dev/null 2>&1 &

# Later... if you need to stop immediately
./nice_rsync_stop.sh
```

### Status Commands

| Action | Command |
|--------|---------|
| Check scheduler status | `ps aux \| grep scheduler` |
| Check rsync status | `ps aux \| grep nice_rsync` |
| View scheduler logs | `tail -f /home/ubuntu/logs/scheduler-*.log` |
| View rsync logs | `tail -f /home/ubuntu/logs/rsync-*.log` |
| Check backup status | `cat /home/ubuntu/logs/backup.status` |
| Emergency stop | `./nice_rsync_stop.sh` |

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

## Author

Created for reliable rsync backups on devices with limited resources.
