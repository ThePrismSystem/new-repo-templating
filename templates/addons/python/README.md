# python

Python 3.13 modules and scripts, tested with the standard library's
`unittest`. Combines with any other addon.

## What it adds

- ruff with pycodestyle (`E`, `W`), Pyflakes (`F`), bugbear (`B`), bandit's
  security checks (`S`), import sorting (`I`) and pyupgrade (`UP`); tests
  can use plain `assert`
- `ruff format` as the formatter
- `requirements-dev.txt` with ruff and coverage.py pinned by version and
  hash, so `pip install --require-hashes` refuses anything else. Renovate
  updates the versions and the hashes together
- coverage.py with branch coverage over all of `src/`, failing under 80%.
  A module no test imports counts as uncovered
- `.python-version` for `actions/setup-python` and pyenv

`setup.sh` creates `.venv` and installs the dev requirements into it.

## Checks

`scripts/check-python.sh <step>` runs each check. CI runs one step per job,
and every job is a required check. The script uses `.venv` when it exists.

| Step | CI job | Runs |
|---|---|---|
| `lint` | `python-lint` | `ruff check`, `ruff format --check` |
| `test` | `python-test` | `unittest` under coverage.py, `coverage/python.xml` uploaded to Codecov under the `python` flag |

CodeQL scans it as `python`.

## In the generated project

Code lives in `src/` and tests in `tests/`. Tests import modules from `src/`
by name, so run them with `src` on the path:

```sh
PYTHONPATH=src .venv/bin/python -m unittest discover -s tests
```

`ruff check --fix .` and `ruff format .` fix what they can.
