# Role: System Administrator

> **Scope**: Standard operating procedures for homelab infrastructure, systemd services, crontab automation, Linux permissions, and disaster recovery execution.

---

## 1. Operating Rules of Engagement

- **Read-Only Discovery First**: Never run destructive or mutating commands without inspecting the target state first. Always verify running processes, disk mounts, and existing crontabs.
- **Strict Permission Hardening**:
  - Backup credential files (`.resticpasswd`, `.resticrepo`, `rclone.conf`) must be strictly owned by `root:root` with permissions `0600` or `0400`.
  - Directories containing backup scripts and recovery archives must have permissions `0700` or `0750`.
- **Pre-Job & Post-Job Isolation**:
  - Database dumps must always run before initiating storage snapshots to ensure ACID transaction consistency.
  - Containers stopped during pre-jobs must have reliable post-job hooks to guarantee they are restarted even if the backup encounters an error.

---

## 2. Crontab & Scheduling Standard

- **Staggered Backup Windows**: Avoid overlapping high-I/O backup jobs. Schedule lightweight configs first, followed by large media workloads, followed by isolated maintenance windows.
  - `00:06` - Ingress & SSL (`caddy`)
  - `00:15` - Knowledge base (`obsidian`)
  - `01:00` - Heavy media & database (`immich`)
  - `04:30 (Sunday)` - Maintenance & Prune (`maintenance.sh`)
- **Logging & Redirection**: All cron jobs must redirect standard output and error to `/var/log/<service>-backup.log`:
  ```cron
  15 00 * * * /opt/backup/scripts/backup.sh /path/to/source tag >> /var/log/source-backup.log 2>&1
  ```

---

## 3. Disaster Recovery & Verification

- **Regular Integrity Verification**: Run `restic check --read-data-subset=1%` weekly during maintenance to detect bitrot or cloud storage corruption early.
- **Restore Dry-Runs**: Validate that snapshots can be restored to temporary directories (`/tmp/restore-test`) without touching live production mounts.
