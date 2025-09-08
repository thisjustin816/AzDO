Describe 'Import-AzDOWorkItemProcess' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force

        # Set up environment variables to avoid authentication errors
        $env:SYSTEM_ACCESSTOKEN = 'fake-token'
        $env:SYSTEM_COLLECTIONURI = 'https://dev.azure.com/TestOrg'

        # Simple test process definition
        $testProcessDefinition = @{
            name          = 'TestProcess'
            typeId        = 'test-process-id'  # Required field
            description   = 'Test process description'
            fields        = @(
                @{
                    referenceName = 'System.Title'
                    name          = 'Title'
                    type          = 'string'
                },
                @{
                    referenceName = 'Custom.TestField'
                    name          = 'Test Field'
                    type          = 'string'
                }
            )
            workItemTypes = @(
                @{
                    name          = 'Bug'
                    referenceName = 'Bug'  # Required field
                    fields        = @(
                        @{
                            referenceName = 'System.Title'
                        }
                    )
                }
            )
        }

        # Create test files in TestDrive
        $script:testProcessPath = "$TestDrive\TestProcess.json"
        $testProcessDefinition | ConvertTo-Json -Depth 10 | Set-Content -Path $script:testProcessPath

        # Mock REST API calls for existing process
        Mock -CommandName Invoke-AzDORestApiMethod -MockWith {
            param($Endpoint, $Method, $Body)
            switch -Regex ($Endpoint) {
                'work/processes$' {
                    if ($Method -eq 'Get') {
                        @(
                            @{
                                name   = 'TestProcess'
                                typeId = 'existing-process-id'
                            }
                        )
                    }
                    else {
                        @{
                            name = ($Body | ConvertFrom-Json).name
                            typeId = 'new-process-id'
                        }
                    }
                }
                'work/processes/[\w-]+/fields$' {
                    @{ id = 'field-id' }
                }
                'work/processes/[\w-]+/workitemtypes$' {
                    $bodyObj = $Body | ConvertFrom-Json
                    @{
                        name = $bodyObj.name
                        referenceName = $bodyObj.referenceName
                    }
                }
                default {
                    @{ success = $true }
                }
            }
        }

        # Mock Write-Progress
        Mock -CommandName Write-Progress -MockWith { }
    }

    Context 'When Force parameter is used' {
        It 'should import without confirmation' {
            # Act
            $result = Import-AzDOWorkItemProcess -Path $script:testProcessPath -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'TestProcess'
        }
    }

    Context 'When ShouldProcess is tested' {
        BeforeAll {
            # Mock ShouldProcess to return false (user says No)
            Mock -CommandName 'Write-Host' -MockWith { }
        }

        It 'should respect WhatIf parameter' {
            # Act & Assert - should not throw when WhatIf is used
            { Import-AzDOWorkItemProcess -Path $script:testProcessPath -WhatIf } | Should -Not -Throw
        }
    }

    Context 'When processing JSON format' {
        It 'should accept valid JSON file' {
            # Act
            $result = Import-AzDOWorkItemProcess -Path $script:testProcessPath -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-AzDORestApiMethod -Exactly -Times 1 -ParameterFilter {
                $Endpoint -match 'work/processes$' -and $Method -eq 'Get'
            }
        }

        It 'should handle process with custom fields' {
            # Arrange
            $processWithCustomFields = @{
                name          = 'CustomProcess'
                typeId        = 'custom-process-id'
                description   = 'Process with custom fields'
                fields        = @(
                    @{
                        referenceName = 'Custom.Priority'
                        name          = 'Priority'
                        type          = 'string'
                    }
                )
                workItemTypes = @(
                    @{
                        name          = 'Task'
                        referenceName = 'Task'
                    }
                )
            }
            $customProcessPath = "$TestDrive\CustomProcess.json"
            $processWithCustomFields | ConvertTo-Json -Depth 10 | Set-Content -Path $customProcessPath

            # Act
            $result = Import-AzDOWorkItemProcess -Path $customProcessPath -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-AzDORestApiMethod -ParameterFilter {
                $Endpoint -match 'fields$' -and $Method -eq 'Post'
            }
        }

        It 'should handle malformed JSON gracefully' {
            # Arrange
            $invalidJsonPath = "$TestDrive\Invalid.json"
            '{ "name": "Test", invalid json }' | Set-Content -Path $invalidJsonPath

            # Act & Assert
            { Import-AzDOWorkItemProcess -Path $invalidJsonPath -Force } | Should -Throw
        }
    }

    Context 'When importing existing process' {
        BeforeAll {
            # Override mock to return existing process
            Mock -CommandName Invoke-AzDORestApiMethod -MockWith {
                param($Endpoint, $Method, $Body)
                switch -Regex ($Endpoint) {
                    'work/processes$' {
                        if ($Method -eq 'Get') {
                            @(
                                @{
                                    name   = 'TestProcess'
                                    typeId = 'existing-process-id'
                                }
                            )
                        }
                    }
                    'work/processes/[\w-]+/fields$' {
                        @{ id = 'field-id' }
                    }
                    'work/processes/[\w-]+/workitemtypes$' {
                        $bodyObj = $Body | ConvertFrom-Json
                        @{
                            name = $bodyObj.name
                            referenceName = $bodyObj.referenceName
                        }
                    }
                    default {
                        @{ success = $true }
                    }
                }
            }
        }

        It 'should use existing process and import components' {
            # Act
            $result = Import-AzDOWorkItemProcess -Path $script:testProcessPath -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.typeId | Should -Be 'existing-process-id'

            # Should not try to create a new process
            Should -Invoke Invoke-AzDORestApiMethod -Exactly -Times 0 -ParameterFilter {
                $Endpoint -match 'work/processes$' -and $Method -eq 'Post'
            }

            # Should import fields and work item types to existing process
            Should -Invoke Invoke-AzDORestApiMethod -ParameterFilter {
                $Endpoint -match 'fields$' -and $Method -eq 'Post'
            }
        }
    }

    Context 'When importing new process' {
        BeforeAll {
            # Override mock to return no existing processes
            Mock -CommandName Invoke-AzDORestApiMethod -MockWith {
                param($Endpoint, $Method, $Body)
                switch -Regex ($Endpoint) {
                    'work/processes$' {
                        if ($Method -eq 'Get') {
                            @()  # No existing processes
                        }
                        else {
                            @{
                                name   = ($Body | ConvertFrom-Json).name
                                typeId = 'new-process-id'
                            }
                        }
                    }
                    'work/processes/[\w-]+/fields$' {
                        @{ id = 'field-id' }
                    }
                    'work/processes/[\w-]+/workitemtypes$' {
                        $bodyObj = $Body | ConvertFrom-Json
                        @{
                            name           = $bodyObj.name
                            referenceName  = $bodyObj.referenceName
                        }
                    }
                    default {
                        @{ success = $true }
                    }
                }
            }
        }

        It 'should create new process when none exists' {
            # Act
            $result = Import-AzDOWorkItemProcess -Path $script:testProcessPath -Force

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.typeId | Should -Be 'new-process-id'

            # Should create a new process
            Should -Invoke Invoke-AzDORestApiMethod -Exactly -Times 1 -ParameterFilter {
                $Endpoint -match 'work/processes$' -and $Method -eq 'Post'
            }
        }
    }
}
