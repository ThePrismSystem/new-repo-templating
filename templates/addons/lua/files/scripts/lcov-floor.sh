#!/usr/bin/env bash
# Fails when the line coverage in an LCOV report is under a floor, summing the
# LH (lines hit) and LF (lines found) records of every file in it.
#
# Usage: lcov-floor.sh <lcov-file> <percent>

main() {
  set -euo pipefail
  if (($# != 2)); then
    echo "Usage: $0 <lcov-file> <percent>" >&2
    exit 2
  fi
  local report="$1" floor="$2"
  if [[ ! -r "$report" ]]; then
    echo "Error: can't read $report" >&2
    exit 2
  fi
  awk -F: -v floor="$floor" '
    $1 == "LH" { hit += $2 }
    $1 == "LF" { found += $2 }
    END {
      if (found == 0) {
        print "No lines to count in the coverage report."
        exit 1
      }
      percent = 100 * hit / found
      printf "Line coverage: %.2f%% (%d of %d lines), floor %s%%\n", percent, hit, found, floor
      exit percent < floor ? 1 : 0
    }
  ' "$report"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
