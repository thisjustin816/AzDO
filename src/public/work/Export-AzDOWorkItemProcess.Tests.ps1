Describe 'Export-AzDOWorkItemProcess' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }

    Context 'when the process exists' {
        It 'should export the process definition as json' {
            $processName = 'Agile'
            $result = Export-AzDOWorkItemProcess -ProcessName $processName -Destination $TestDrive

            $result | Should -Not -BeNullOrEmpty
            $result.FullName | Should -Be "$TestDrive/$processName.json"

            $content = Get-Content -Path $result.FullName -Raw | ConvertFrom-Json
            $content.name | Should -Be $processName
        }
    }

    Context 'when the process does not exist' {
        It 'should throw an error' {
            { Export-AzDOWorkItemProcess -ProcessName 'NonExistentProcess' -Destination $TestDrive } |
                Should -Throw "Process 'NonExistentProcess' not found."
        }
    }
}
