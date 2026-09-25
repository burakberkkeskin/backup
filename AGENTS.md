# Agent Operational Guidelines (AGENTS.md)

> **Repository**: `backup` (Public Open-Source Repository)  
> **Purpose**: Generic, modular, and automated backup and disaster recovery framework using Restic and Rclone.  
> **Audience**: AI Agents (Antigravity, Claude Code, Cursor, Copilot) and DevOps Engineers.

---

## 1. Public Repository & Generic Code Standard (Non-Negotiable)

1. **Public Open-Source Invariant**: This is a **PUBLIC repository**. All code, documentation, examples, and scripts must remain **100% generic, reusable, and infrastructure-agnostic**.
2. **Absolute Zero Secrets**: NEVER commit passwords, repository URLs with credentials, webhook tokens, API keys, or private notification topics/URLs.
3. **No Private Network Metadata**: NEVER commit personal domain names, private/public IP addresses, or internal hostnames. Always use RFC placeholders (e.g. `example.com`, `203.0.113.x`, `/path/to/source`).
4. **Externalized Configuration**: All environment-specific variables and secrets must be loaded from external, uncommitted files (e.g. `/etc/backup/config.env`, `/root/.resticpasswd`, `/root/.resticrepo`, `/root/.config/rclone/rclone.conf`).
5. **Sanitized Templates Only**: Provide only sanitized configuration templates (e.g. `scripts/config.env.example`) using `<REDACTED>` or placeholder values.

---

## 2. Directory Architecture

```text
.
├── AGENTS.md                  # This file: Agent operational guidelines
├── README.md                  # Human-facing architecture and runbook
├── roles/                     # Specialized role guides (bash-script-writer, system-admin)
├── scripts/
│   ├── backup.sh              # Core incremental backup runner
│   ├── maintenance.sh         # Retention (forget), prune, and check runner
│   ├── config.env.example     # Template for external environment variables
│   ├── lib/                   # Shared libraries (logging, notifications, validation)
│   ├── pre-jobs/              # Pre-execution hooks (database dumps, stop service)
│   └── post-job/              # Post-execution hooks (restart service)
└── recovery-codes/            # Standalone recovery code backup tools
```

---

## 3. Script Writing Guidelines

Agents modifying or authoring scripts in this repository must adopt the role rules defined in [`roles/bash-script-writer.md`](roles/bash-script-writer.md):
- Enforce `set -euo pipefail`.
- Never use `eval` for command execution; use native Bash arrays.
- All code, comments, log messages, and error outputs must be in **English**.
- Log messages must use `scripts/lib/log.sh` helpers (`log_info`, `log_error`, `log_debug`).

---

## 4. Execution & Testing Protocol

- **Dry-Run First**: When testing retention policies or prune operations, always invoke with `--dry-run` or simulate in safe mode first.
- **Lock Awareness**: Be aware that `prune` and `check` require exclusive locks on the Restic repository. Never schedule maintenance concurrently with active backup jobs.
