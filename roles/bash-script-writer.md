# Role: Bash Script Writer

> **Scope**: Standard operating procedures, coding standards, and safety invariants for writing shell scripts in the backup repository.

---

## 1. Core Principles & Safety Invariants

- **Strict Mode**: Every script must start with:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  ```
- **Never Use `eval`**: Avoid `eval` for command execution. Use native Bash arrays (`cmd=()`, `cmd+=()`, `"${cmd[@]}"`) to safely handle arguments containing whitespace or special characters.
- **Quote Everything**: Always double-quote variable expansions (`"$VAR"`, `"${ARRAY[@]}"`) to prevent word splitting and globbing.
- **Fail Fast & Explicit Exits**: Validate all prerequisites, input arguments, and files before executing operations. Return non-zero exit codes on failure.
- **Zero Hardcoded Secrets**: NEVER hardcode passwords, API keys, private tokens, or webhook URLs in shell scripts. Always read from environment variables or permission-restricted files (e.g. `/root/.resticpasswd`).

---

## 2. Code Structure & Conventions

- **Functions First**: Organize logic into small, single-purpose functions.
- **Local Scope**: Always declare function variables with `local` or `local -a` (for arrays).
- **Standardized Logging**: Use the shared logging module (`scripts/lib/log.sh`). Log with timestamps, log levels (`[INFO]`, `[DEBUG]`, `[ERROR]`), and redirect output to appropriate channels.
- **Safe Traps & Cleanup**: If temporary files are created (`mktemp`), always register an `EXIT` trap to clean them up:
  ```bash
  TMP_FILE=$(mktemp)
  trap 'rm -f "$TMP_FILE"' EXIT
  ```

---

## 3. Tooling & ShellCheck

- Code must pass `shellcheck` with zero warnings where feasible.
- Use POSIX-compliant constructs when writing portable scripts; take advantage of standard Bash 4+ features (arrays, parameter expansion) when running under Bash.
