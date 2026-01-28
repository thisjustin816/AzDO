Describe 'Get-AzDOPipelineRunLog' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force

        $script:Project = 'Tools'
        $script:BuildId = 392244
    }

    It 'should download an archive of all logs' {
        $logs = Get-AzDOPipelineRunLog `
            -BuildId $script:BuildId `
            -Project $script:Project `
            -Destination $TestDrive `
            -NoRetry

        $logs.FullName | Should -Exist
        { Expand-Archive -Path $logs.FullName -DestinationPath $TestDrive } |
            Should -Not -Throw
    }

    It 'should output logs to console' {
        $logs = Get-AzDOPipelineRunLog `
            -BuildId $script:BuildId `
            -Project $script:Project `
            -NoRetry

        ($logs -join "`n") | Should -Match $script:BuildId
    }
}
