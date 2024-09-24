Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }

    It 'should get the README contents for this repo' {
        Get-AzDOGitItem `
            -Path README.md `
            -Branch main `
            -AzDORepository AzDOCmd `
            -Project Tools |
            Should -Match '## AzDOCmd Cmdlets'
    }

    It 'should save the README for this repo to a file' {
        Get-AzDOGitItem `
            -Path README.md `
            -Branch main `
            -AzDORepository AzDOCmd `
            -Project Tools `
            -OutFile "$TestDrive/README.md"
        ( Get-Content -Path "$TestDrive/README.md" ) -join "`n" |
            Should -Match '## AzDOCmd Cmdlets'
    }

    It 'should save a valid version of a binary file' {
        Get-AzDOGitItem `
            -Path nuget.exe `
            -Branch main `
            -AzDORepository PipelineTasks `
            -Project Tools `
            -OutFile "$TestDrive/nuget.exe"

        { & "$TestDrive/nuget.exe" } | Should -Not -Throw
    }
}
