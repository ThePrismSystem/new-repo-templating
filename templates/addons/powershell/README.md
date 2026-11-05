# powershell

PowerShell modules and scripts that run on both Windows PowerShell 5.1 and
PowerShell 7. Combines with any other addon.

## What it adds

- PSScriptAnalyzer at Error, Warning and Information severity, with
  `PSUseCompatibleSyntax` checking that every file parses on 5.1 and 7.0,
  over every PowerShell file git doesn't ignore
- InjectionHunter's rules for code that passes input to `Invoke-Expression`,
  `Add-Type` and similar commands
- Analyzer findings uploaded to code scanning as SARIF on public repos
- Pester 6 with JaCoCo coverage over every file in `src/`, failing under 80%.
  The tests run on `ubuntu-latest` under PowerShell 7 and on
  `windows-latest` under Windows PowerShell 5.1, and each run uploads to
  Codecov under the `powershell` flag

CI installs PSScriptAnalyzer, InjectionHunter and Pester from the PowerShell
Gallery at pinned versions, and Renovate updates them.

There's no CodeQL language for PowerShell.

## Checks

`scripts/check-powershell.ps1 <step>` runs each check, on either PowerShell.
`scripts/check-powershell.sh` runs it under `pwsh` for tools that expect a
shell script. CI runs one step per job, and every job is a required check.

| Step | CI job | Runs |
|---|---|---|
| `lint` | `powershell-lint` | PSScriptAnalyzer with `PSScriptAnalyzerSettings.psd1` and InjectionHunter |
| `test` | `powershell-test (ubuntu-latest)`, `powershell-test (windows-latest)` | Pester with coverage to `coverage/powershell.xml` |

## In the generated project

Install the modules once:

```powershell
Install-Module PSScriptAnalyzer, InjectionHunter -Scope CurrentUser
Install-Module Pester -Scope CurrentUser -SkipPublisherCheck
```

Editors that read `PSScriptAnalyzerSettings.psd1` apply the severity and
compatibility settings. InjectionHunter's rules only run from the check
script, which passes them to the analyzer from the installed module.
