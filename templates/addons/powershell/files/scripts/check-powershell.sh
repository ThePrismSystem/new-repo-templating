#!/usr/bin/env bash
# Runs scripts/check-powershell.ps1 under PowerShell 7. The checks live in the
# .ps1 so Windows PowerShell 5.1 can run them too; this wrapper gives verify.sh
# and the other addons the same scripts/check-<addon>.sh entry point.

main() {
  set -euo pipefail
  exec pwsh -NoProfile -NonInteractive -File "$(dirname "${BASH_SOURCE[0]}")/check-powershell.ps1" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
