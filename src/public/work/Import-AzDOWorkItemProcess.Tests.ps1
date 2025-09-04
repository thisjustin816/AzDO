Describe 'Import-AzDOWorkItemProcess' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force

        # Mock REST API calls
        Mock -CommandName Invoke-AzDORestApiMethod -MockWith {
            $endpoint = $args[0].Endpoint
            switch -Regex ($endpoint) {
                'work/processes$' {
                    if ($Method -eq 'Get') {
                        @(
                            @{
                                name   = 'Agile'
                                typeId = 'agile-id'
                            }
                        )
                    }
                    else {
                        @{
                            name = $Body.name
                            typeId = 'new-process-id'
                        }
                    }
                }
                'work/processes/[\w-]+$' {
                    @{
                        name = $Body.name
                        typeId = 'updated-process-id'
                    }
                }
                'work/processes/[\w-]+/fields$' {
                    @{ id = 'field-id' }
                }
                'work/processes/[\w-]+/behaviors$' {
                    @{ id = 'behavior-id' }
                }
                'work/processes/[\w-]+/workitemtypes$' {
                    @{
                        name = $Body.name
                        referenceName = $Body.referenceName
                    }
                }
                'work/processes/[\w-]+/workitemtypes/[\w\.]+$' {
                    @{
                        name = $Body.name
                        referenceName = $witName
                    }
                }
                'workitemtypes/.+/(states|fields|rules|behaviors|layout)$' {
                    @{ id = 'component-id' }
                }
                default { @{} }
            }
        } -ParameterFilter { $true }

        # Create a complete test process definition
        $testProcessDefinition = @{
            name = "Test Process $(New-Guid)"
            description = "Test process created by Pester"
            fields = @(
                @{
                    name = "Custom Field"
                    type = "String"
                }
            )
            behaviors = @(
                @{
                    name = "Custom Behavior"
                    color = "#FF0000"
                }
            )
            workItemTypes = @(
                @{
                    name = "Custom Work Item"
                    referenceName = "Custom.WorkItem"
                    description = "A custom work item type"
                    color = "#00FF00"
                    icon = "icon-test"
                    isDisabled = $false
                    states = @(
                        @{
                            name = "New"
                            color = "#FFFFFF"
                            stateCategory = "Proposed"
                        }
                    )
                    fields = @(
                        @{
                            name = "Custom WIT Field"
                            referenceName = "Custom.Field"
                            type = "String"
                        }
                    )
                    rules = @(
                        @{
                            conditions = @()
                            actions = @()
                        }
                    )
                    behaviors = @(
                        @{
                            behavior = @{
                                name = "Custom WIT Behavior"
                            }
                        }
                    )
                    layout = @{
                        pages = @(
                            @{
                                label = "Details"
                                groups = @()
                            }
                        )
                    }
                }
            )
        }
        $script:testFilePath = "$TestDrive/test-process.json"
        $testProcessDefinition | ConvertTo-Json -Depth 100 | Set-Content -Path $script:testFilePath
    }

    Context 'when importing a new process' {
        It 'should create the process with all components when confirmed' {
            $result = Import-AzDOWorkItemProcess -Path $script:testFilePath -Confirm:$false

            # Verify basic process creation
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be ($testProcessDefinition | ConvertFrom-Json).name

            # Verify API calls for process components
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -eq 'work/processes' -and $Method -eq 'Post'
            }
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'work/processes/.+/fields$'
            }
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'work/processes/.+/behaviors$'
            }
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'work/processes/.+/workitemtypes$'
            }
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/states$'
            }
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/fields$'
            }
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/rules$'
            }
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/behaviors$'
            }
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/layout$'
            }
        }

        It 'should not create the process when not confirmed' {
            Mock -CommandName ShouldProcess -MockWith { $false }
            $result = Import-AzDOWorkItemProcess -Path $script:testFilePath
            $result | Should -BeNullOrEmpty
            Should -Not -Invoke Invoke-AzDORestApiMethod -ParameterFilter {
                $endpoint -eq 'work/processes' -and $Method -eq 'Post'
            }
        }
    }

    Context 'when importing an existing process' {
        BeforeAll {
            $script:existingProcessPath = "$TestDrive/existing-process.json"
            $testProcessDefinition.name = 'Agile'
            $testProcessDefinition | ConvertTo-Json -Depth 100 | Set-Content -Path $script:existingProcessPath
        }

        It 'should update with -Force when confirmed' {
            $result = Import-AzDOWorkItemProcess -Path $script:existingProcessPath -Force -Confirm:$false

            # Verify basic process update
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'Agile'

            # Verify API calls for process components
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match '^work/processes/agile-id$' -and $Method -eq 'Put'
            }
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'work/processes/.+/fields$'
            }
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'work/processes/.+/behaviors$'
            }
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/states$'
            }
        }

        It 'should not update with -Force when not confirmed' {
            Mock -CommandName ShouldProcess -MockWith { $false }
            $result = Import-AzDOWorkItemProcess -Path $script:existingProcessPath -Force
            $result | Should -BeNullOrEmpty
            Should -Not -Invoke Invoke-AzDORestApiMethod -ParameterFilter {
                $endpoint -match '^work/processes/agile-id$' -and $Method -eq 'Put'
            }
        }

        It 'should update when confirmed without -Force' {
            Mock -CommandName ShouldContinue -MockWith { $true }
            $result = Import-AzDOWorkItemProcess -Path $script:existingProcessPath -Confirm:$false
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be 'Agile'
            Should -Invoke Invoke-AzDORestApiMethod -Times 1 -ParameterFilter {
                $endpoint -match '^work/processes/agile-id$' -and $Method -eq 'Put'
            }
        }

        It 'should not update when not confirmed without -Force' {
            Mock -CommandName ShouldContinue -MockWith { $false }
            $result = Import-AzDOWorkItemProcess -Path $script:existingProcessPath
            $result | Should -BeNullOrEmpty
            Should -Not -Invoke Invoke-AzDORestApiMethod -ParameterFilter {
                $endpoint -match '^work/processes/agile-id$' -and $Method -eq 'Put'
            }
        }

        It 'should handle API errors gracefully' {
            Mock -CommandName Invoke-AzDORestApiMethod -MockWith { throw 'API Error' } -ParameterFilter {
                $endpoint -match 'workitemtypes/.+/fields$'
            }

            # Should not throw but should write warning
            { Import-AzDOWorkItemProcess -Path $script:existingProcessPath -Force -Confirm:$false } |
                Should -Not -Throw

            Should -Invoke Write-Warning
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
