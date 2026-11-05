BeforeAll {
    Import-Module "$PSScriptRoot/../src/Names.psm1" -Force
}

Describe 'Get-DisplayName' {
    It 'joins the parts with single spaces' {
        Get-DisplayName -Part 'Ada', 'Lovelace' | Should -Be 'Ada Lovelace'
    }

    It 'trims each part and leaves out blank ones' {
        Get-DisplayName -Part '  Ada ', '', '   ', 'Lovelace' | Should -Be 'Ada Lovelace'
    }

    It 'returns an empty string for no parts' {
        Get-DisplayName | Should -Be ''
    }
}
