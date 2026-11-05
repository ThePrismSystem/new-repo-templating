@{
    # Information is where the analyzer keeps its style rules, such as
    # comment-based help on exported functions.
    Severity            = @('Error', 'Warning', 'Information')
    IncludeDefaultRules = $true
    Rules               = @{
        # Code has to parse on both Windows PowerShell 5.1 and PowerShell 7.
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0')
        }
    }
}
