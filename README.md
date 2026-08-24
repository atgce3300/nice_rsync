# nice_rsync

This is a wrapper script that does pre-flight checks, runs the hardened rsync, retries on transient failures, and is safe to re-run (lock + resume). Save this as /home/ubuntu/nice_rsync.sh on the source machine:

How the script guarantees success:

Pre-flight gates — local drive mounted? remote reachable? remote has disk space? No point starting otherwise.
Resumable — --partial means an interrupted transfer continues from where it left off on the next attempt, so retries don't restart from zero.
Retry loop — transient failures (exit 11/12/23/35/255: network, IO, protocol, ssh) are retried up to 5× with a 60s pause. Exit 24 (files changed/deleted mid-run) is treated as success, which is correct for backups.
flock lock — if you accidentally run it twice (or cron fires while a manual run is active), the second instance exits instead of corrupting things.
Status + logs — every attempt is timestamped into /home/ubuntu/logs/rsync-<date>.log; the final verdict (OK/FAILED + time) is always in backup.status, so you can check success with one command: cat /home/ubuntu/logs/backup.status.
No hangs — BatchMode, ConnectTimeout, ServerAliveInterval mean a dead tunnel fails fast instead of hanging forever.
Setup:

chmod +x /home/ubuntu/nice_rsync.sh
/home/ubuntu/nice_rsync.sh          # run once manually to test


Run it detached so SSH disconnects don't kill it (better than & disown):

tmux new -d -s backup '/home/ubuntu/nice_rsync.sh'
tmux attach -t backup              # watch progress anytime


Or schedule it (lock makes re-runs safe):
crontab -e
# 0 3 * * * /home/ubuntu/nice_rsync.sh


Two notes:

If ubuntu on the remote doesn't have passwordless sudo, change --rsync-path to --rsync-path="nice -n 19 ionice -c 3 rsync".

Run the first manual test while you're watching it, then check cat /home/ubuntu/logs/backup.status after — that's your "did it succeed" single source of truth. If it still dies hours in, check the remote's dmesg/journalctl as before, because that points at hardware (USB power/thermal or RAM), which no script can fix.
