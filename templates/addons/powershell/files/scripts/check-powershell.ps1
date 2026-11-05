<#
.SYNOPSIS
The PowerShell checks. Each job in .github/workflows/powershell.yml runs one
step; run `all` locally before pushing.

.DESCRIPTION
lint  PSScriptAnalyzer with PSScriptAnalyzerSettings.psd1 and InjectionHunter's
      rules, over every PowerShell file git doesn't ignore. With SARIF_DIR set,
      the findings also go to $env:SARIF_DIR/powershell.sarif.
test  Pester with JaCoCo coverage of src/ in coverage/powershell.xml, failing
      under 80%.
all   Every step above.

Needs PSScriptAnalyzer, InjectionHunter and Pester 6 from Install-Module.
Runs on Windows PowerShell 5.1 and PowerShell 7.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('lint', 'test', 'all')]
    [string] $Step
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$CoverageFloor = 80
$Root = Split-Path -Parent $PSScriptRoot

function Get-RepoPath {
    param([string] $Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        $full = $full.Substring($Root.Length).TrimStart('\', '/')
    }
    return $full.Replace('\', '/')
}

function ConvertTo-SarifLevel {
    param([string] $Severity)
    switch ($Severity) {
        'Information' { return 'note' }
        'Warning' { return 'warning' }
        default { return 'error' }
    }
}

# PSScriptAnalyzer has no SARIF output, so its findings are converted here.
function Export-Sarif {
    param(
        [object[]] $Finding,
        [string] $Version,
        [string] $Path
    )
    $rules = @($Finding | Sort-Object -Property RuleName -Unique | ForEach-Object {
            @{ id = $_.RuleName; shortDescription = @{ text = $_.RuleName } }
        })
    $results = @(foreach ($item in $Finding) {
            @{
                ruleId    = $item.RuleName
                level     = ConvertTo-SarifLevel -Severity $item.Severity.ToString()
                message   = @{ text = $item.Message }
                locations = @(@{
                        physicalLocation = @{
                            artifactLocation = @{ uri = Get-RepoPath -Path $item.ScriptPath }
                            region           = @{
                                startLine   = [Math]::Max(1, $item.Line)
                                startColumn = [Math]::Max(1, $item.Column)
                            }
                        }
                    })
            }
        })
    $sarif = [ordered]@{
        '$schema' = 'https://json.schemastore.org/sarif-2.1.0.json'
        version   = '2.1.0'
        runs      = @(@{
                tool    = @{
                    driver = @{
                        name           = 'PSScriptAnalyzer'
                        informationUri = 'https://github.com/PowerShell/PSScriptAnalyzer'
                        version        = $Version
                        rules          = $rules
                    }
                }
                results = $results
            })
    }
    $target = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    $json = $sarif | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($target, $json, (New-Object System.Text.UTF8Encoding $false))
}

function Invoke-Lint {
    $analyzer = Import-Module -Name PSScriptAnalyzer -PassThru
    $hunter = Get-Module -ListAvailable -Name InjectionHunter |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
    if (-not $hunter) {
        throw 'InjectionHunter is missing. Install it with: Install-Module InjectionHunter -Scope CurrentUser'
    }
    $settings = Join-Path -Path $Root -ChildPath 'PSScriptAnalyzerSettings.psd1'
    # Untracked files count too, so a new script is checked before it's added.
    $files = @(git ls-files --cached --others --exclude-standard -- '*.ps1' '*.psm1' '*.psd1' |
            Sort-Object -Unique |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    $findings = @(foreach ($file in $files) {
            Invoke-ScriptAnalyzer -Path $file -Settings $settings -CustomRulePath $hunter.Path -IncludeDefaultRules
        })
    if ($env:SARIF_DIR) {
        Export-Sarif -Finding $findings -Version $analyzer.Version.ToString() `
            -Path (Join-Path -Path $env:SARIF_DIR -ChildPath 'powershell.sarif')
    }
    if ($findings.Count -gt 0) {
        $findings |
            Format-Table -AutoSize -Property Severity, RuleName, ScriptName, Line, Message |
            Out-String -Width 4096
        Write-Output "PSScriptAnalyzer found $($findings.Count) problem(s) in $($files.Count) file(s)."
        exit 1
    }
    Write-Output "PSScriptAnalyzer found no problems in $($files.Count) file(s)."
}

function Invoke-Test {
    $pester = Get-Module -ListAvailable -Name Pester |
        Where-Object { $_.Version.Major -ge 6 } |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1
    if (-not $pester) {
        throw 'Pester 6 is missing. Install it with: Install-Module Pester -Scope CurrentUser -SkipPublisherCheck'
    }
    Import-Module -ModuleInfo $pester -Force

    New-Item -ItemType Directory -Force -Path (Join-Path -Path $Root -ChildPath 'coverage') | Out-Null
    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path -Path $Root -ChildPath 'tests'
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = Join-Path -Path $Root -ChildPath 'src'
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath = Join-Path -Path $Root -ChildPath 'coverage/powershell.xml'
    $config.CodeCoverage.CoveragePercentTarget = $CoverageFloor

    $result = Invoke-Pester -Configuration $config
    if ($result.FailedCount -gt 0) {
        exit 1
    }
    # Pester measures every file under src/, so a module no test imports
    # counts as uncovered.
    $percent = $result.CodeCoverage.CoveragePercent
    if ($percent -lt $CoverageFloor) {
        Write-Output ('Coverage of {0:N2}% is under the {1}% floor.' -f $percent, $CoverageFloor)
        exit 1
    }
    Write-Output ('Coverage: {0:N2}%, floor {1}%.' -f $percent, $CoverageFloor)
}

Push-Location -Path $Root
try {
    switch ($Step) {
        'lint' { Invoke-Lint }
        'test' { Invoke-Test }
        'all' {
            Write-Output '-- lint'
            Invoke-Lint
            Write-Output '-- test'
            Invoke-Test
        }
    }
}
finally {
    Pop-Location
}
