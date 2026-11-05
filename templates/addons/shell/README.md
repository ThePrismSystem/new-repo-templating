# shell

Bash scripts, linted with shellcheck and shfmt and tested with bats. Combines
with any other addon, and then checks that addon's scripts too.

## What it adds

- shellcheck at `style` severity, following `source` lines, over every `*.sh`
  and `*.bats` file git doesn't ignore
- shfmt with two-space indents and indented `case` branches (`-i 2 -ci`)
- bats for tests, in `tests/`
- A starter script, `src/greet.sh`, that keeps `set -euo pipefail` inside
  `main` so bats can `source` it and call its functions

CI installs shellcheck and shfmt from their release downloads, checked by
SHA-256, and bats from its git tag, checked against the tag's commit. Renovate
updates each version and its hash or commit together.

There's no coverage upload and no CodeQL language for shell.

## Checks

`scripts/check-shell.sh <step>` runs each check. CI runs one step per job,
and every job is a required check.

| Step | CI job | Runs |
|---|---|---|
| `lint` | `shell-lint` | shellcheck, `shfmt -d` |
| `test` | `shell-test` | `bats tests/` |

To run only some tests, set `BATS_FILTER_TAGS` and the `test` step passes it to
`bats --filter-tags`. `BATS_FILTER_TAGS='!slow'` leaves out tests tagged `slow`.

## In the generated project

`shfmt -i 2 -ci -w <file>` fixes formatting. To check a sourced file that
shellcheck can't find from the path in the script, add a
`# shellcheck source=<path from the repo root>` line above the `source`.
