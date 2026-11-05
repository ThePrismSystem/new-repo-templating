# lua

Lua 5.4 modules and scripts, tested with busted. Combines with any other
addon.

## What it adds

- luacheck with the Lua 5.4 standard library, so an assignment to an
  undeclared global fails; specs also get busted's globals
- lua-language-server's diagnostics at warning level, with the busted and
  luassert type definitions it ships, configured in `.luarc.json`
- busted for specs in `spec/`, with `src/` on the module path
- luacov over every module in `src/`, including ones no spec loads, with
  an lcov report for Codecov and `scripts/lcov-floor.sh` failing the run
  under 80% of lines

CI builds Lua 5.4 and LuaRocks with `leafo/gh-actions-lua` and
`leafo/gh-actions-luarocks`, installs each rock at a pinned version, and
downloads lua-language-server checked by SHA-256. Renovate updates the rock
versions from their GitHub tags.

There's no CodeQL language for Lua.

## Checks

`scripts/check-lua.sh <step>` runs each check. CI runs one step per job,
and every job is a required check.

| Step | CI job | Runs |
|---|---|---|
| `lint` | `lua-lint` | luacheck, `lua-language-server --check` |
| `test` | `lua-test` | busted with luacov, `coverage/lua-lcov.info` uploaded to Codecov under the `lua` flag |

## In the generated project

Install the tools once with LuaRocks:

```sh
luarocks install luacheck
luarocks install busted
luarocks install luacov
luarocks install luacov-reporter-lcov
```

lua-language-server comes from its
[releases](https://github.com/LuaLS/lua-language-server/releases) or your
editor's Lua extension.
