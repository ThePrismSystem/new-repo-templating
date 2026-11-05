function Get-DisplayName {
    <#
    .SYNOPSIS
    Joins the parts of a name with single spaces, leaving out blank parts.

    .EXAMPLE
    Get-DisplayName -Part '  Ada ', '', 'Lovelace'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string[]] $Part
    )

    $kept = foreach ($item in $Part) {
        $trimmed = $item.Trim()
        if ($trimmed) {
            $trimmed
        }
    }
    return ($kept -join ' ')
}

Export-ModuleMember -Function Get-DisplayName
