Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        # Remove and re-import the module to ensure latest version is loaded
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $PSScriptRoot '..' 'AzDOCmd.psm1') -Force

        # Dot-source the private functions we're testing
        . (Join-Path $PSScriptRoot 'Import-AzDOProcessField.ps1')

        # Mock dependencies
        Mock Invoke-AzDORestApiMethod {
            param($Uri, $Method, $Body, $Headers, $NoRetry)
            # Function doesn't use the return value, so don't return anything
            # to avoid adding to the output stream
        }
    }

    Context 'when importing process fields' {
        It 'should namespace field reference name with process name' {
            $field = [PSCustomObject]@{
                referenceName = 'Custom.TestField'
                name = 'Test Field'
                type = 'string'
                id = 'some-id'
            }

            $result = Import-AzDOProcessField -Field $field -ProcessName 'MyProcess' -ApiHeaders @{}

            $result.Type | Should -Be 'string'
            $result.Success | Should -BeTrue
            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -ParameterFilter {
                $Body -like '*"referenceName":"MyProcess.Custom.TestField"*'
            } -Exactly 1 -Scope It
        }

        It 'should preserve existing namespace in reference name' {
            $field = [PSCustomObject]@{
                referenceName = 'ExistingProcess.TestField'
                name = 'Test Field'
                type = 'string'
                id = 'some-id'
            }

            $result = Import-AzDOProcessField -Field $field -ProcessName 'MyProcess' -ApiHeaders @{}

            $result.Success | Should -BeTrue
            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -ParameterFilter {
                $Body -like '*"referenceName":"MyProcess.ExistingProcess.TestField"*'
            } -Exactly 1 -Scope It
        }

        It 'should use POST method for field creation' {
            $field = [PSCustomObject]@{
                referenceName = 'Custom.TestField'
                name = 'Test Field'
                type = 'string'
                id = 'some-id'
            }

            Import-AzDOProcessField -Field $field -ProcessName 'MyProcess' -ApiHeaders @{}

            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -ParameterFilter {
                $Method -eq 'POST'
            } -Exactly 1 -Scope It
        }

        It 'should pass NoRetry parameter to API call' {
            $field = [PSCustomObject]@{
                referenceName = 'Custom.TestField'
                name = 'Test Field'
                type = 'string'
                id = 'some-id'
            }

            Import-AzDOProcessField -Field $field -ProcessName 'MyProcess' -ApiHeaders @{} -NoRetry

            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -ParameterFilter {
                $NoRetry -eq $true
            } -Exactly 1 -Scope It
        }

        It 'should handle creation failure when Force is not specified' {
            # Mock POST to fail
            Mock Invoke-AzDORestApiMethod {
                throw "Field already exists"
            }

            $field = [PSCustomObject]@{
                referenceName = 'Custom.ExistingField'
                name = 'Existing Field'
                type = 'string'
                id = 'some-id'
            }

            $result = Import-AzDOProcessField -Field $field -ProcessName 'MyProcess' -ApiHeaders @{}

            $result.Success | Should -BeFalse
            $result.Error | Should -Not -BeNullOrEmpty
        }

        It 'should suppress errors when Force is specified and creation fails' {
            # Mock POST to fail
            Mock Invoke-AzDORestApiMethod {
                throw "Field already exists"
            }

            $field = [PSCustomObject]@{
                referenceName = 'Custom.ExistingField'
                name = 'Existing Field'
                type = 'string'
                id = 'some-id'
            }

            $result = Import-AzDOProcessField -Field $field -ProcessName 'MyProcess' -ApiHeaders @{} -Force

            $result.Success | Should -BeFalse
            $result.Error | Should -Not -BeNullOrEmpty
        }

        It 'should include field type and other properties in the body' {
            $field = [PSCustomObject]@{
                referenceName = 'Custom.TestField'
                name = 'Test Field'
                type = 'integer'
                description = 'A test field'
                id = 'some-id'
            }

            Import-AzDOProcessField -Field $field -ProcessName 'MyProcess' -ApiHeaders @{}

            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -ParameterFilter {
                $Body -like '*"type":"integer"*' -and
                $Body -like '*"name":"Test Field"*' -and
                $Body -like '*"description":"A test field"*'
            } -Exactly 1 -Scope It
        }

        It 'should return structured result with all required properties' {
            $field = [PSCustomObject]@{
                referenceName = 'Custom.TestField'
                name = 'Test Field'
                type = 'string'
                id = 'some-id'
            }

            $result = Import-AzDOProcessField -Field $field -ProcessName 'MyProcess' -ApiHeaders @{}

            $result.Type | Should -Be 'string'
            $result.Success | Should -BeOfType [bool]
            $result.Name | Should -BeOfType [string]
            $result.ReferenceName | Should -BeOfType [string]
        }

        It 'should convert field object to JSON in the body' {
            $field = [PSCustomObject]@{
                referenceName = 'Custom.TestField'
                name = 'Test Field'
                type = 'string'
                id = 'some-id'
            }

            Import-AzDOProcessField -Field $field -ProcessName 'MyProcess' -ApiHeaders @{}

            Should -Invoke -CommandName 'Invoke-AzDORestApiMethod' -ParameterFilter {
                $Body -like '*{*}*'
            } -Exactly 1 -Scope It
        }
    }
}
