Describe 'Import-AzDOWorkItemProcess' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force

        # Create a test process definition file
        $testProcessDefinition = @{
            name        = "Test Process $(New-Guid)"
            description = "Test process created by Pester"
        } | ConvertTo-Json
        $script:testFilePath = "$TestDrive/test-process.json"
        Set-Content -Path $script:testFilePath -Value $testProcessDefinition
    }

    Context 'when importing a new process' {
        It 'should create the process when confirmed' {
            $result = Import-AzDOWorkItemProcess -Path $script:testFilePath -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be ($testProcessDefinition | ConvertFrom-Json).name
        }

        It 'should not create the process when not confirmed' {
            Mock -CommandName ShouldProcess -MockWith { $false }
            $result = Import-AzDOWorkItemProcess -Path $script:testFilePath
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'when importing an existing process' {
        BeforeAll {
            # Export an existing process
            $script:existingProcess = 'Agile'
            $script:existingProcessPath = "$TestDrive/existing-process.json"
            Export-AzDOWorkItemProcess -ProcessName $script:existingProcess -Destination $TestDrive
        }

        It 'should update with -Force when confirmed' {
            $result = Import-AzDOWorkItemProcess -Path $script:existingProcessPath -Force -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be $script:existingProcess
        }

        It 'should not update with -Force when not confirmed' {
            Mock -CommandName ShouldProcess -MockWith { $false }
            $result = Import-AzDOWorkItemProcess -Path $script:existingProcessPath -Force
            $result | Should -BeNullOrEmpty
        }

        It 'should update when confirmed without -Force' {
            Mock -CommandName ShouldContinue -MockWith { $true }
            $result = Import-AzDOWorkItemProcess -Path $script:existingProcessPath -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be $script:existingProcess
        }

        It 'should not update when not confirmed without -Force' {
            Mock -CommandName ShouldContinue -MockWith { $false }
            $result = Import-AzDOWorkItemProcess -Path $script:existingProcessPath
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'when importing an invalid file' {
        BeforeAll {
            # Create an invalid process definition file
            $invalidDefinition = @{
                description = "Invalid process definition"
            } | ConvertTo-Json
            $script:invalidFilePath = "$TestDrive/invalid-process.json"
            Set-Content -Path $script:invalidFilePath -Value $invalidDefinition
        }

        It 'should throw an error' {
            { Import-AzDOWorkItemProcess -Path $script:invalidFilePath } |
                Should -Throw "Invalid process definition file. Missing required field 'name'."
        }
    }
}
