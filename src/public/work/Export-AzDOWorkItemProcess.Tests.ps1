Describe 'Export-AzDOWorkItemProcess - Unit Tests' -Tag 'Unit' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force

        # Stable mock for Initialize-AzDORestApi to avoid external dependencies
        Mock -ModuleName AzDOCmd Initialize-AzDORestApi {
            @{ Authorization = 'Basic fake' }
        }
    }

    Context 'Handles 404 for process fields and aggregates from WITs' {
        BeforeAll {
            # Mock the REST method with endpoint-aware behavior
            Mock -ModuleName AzDOCmd Invoke-AzDORestApiMethod -MockWith {
                param(
                    [Parameter(Mandatory)] $Headers,
                    [Parameter(Mandatory)] $CollectionUri,
                    [Parameter(Mandatory)] $ApiVersion,
                    [Parameter(Mandatory)] $Method,
                    $Project,
                    [Parameter(Mandatory)] $Endpoint,
                    [switch] $NoRetry
                )

                # Mark parameters as used to satisfy analyzer
                $null = $Headers
                $null = $CollectionUri
                $null = $ApiVersion
                $null = $Method
                $null = $Project
                $null = $NoRetry

                switch -Wildcard ($Endpoint) {
                    'work/processes' {
                        # Return a single process matching the ProcessName under test
                        @(
                            [pscustomobject]@{
                                name   = 'MyInheritedProc'
                                typeId = 'proc-123'
                            }
                        )
                        break
                    }
                    'work/processes/proc-123/workitemtypes' {
                        # Two WITs
                        @(
                            [pscustomobject]@{ referenceName = 'Custom.Task' },
                            [pscustomobject]@{ referenceName = 'Microsoft.VSTS.WorkItemTypes.Bug' }
                        )
                        break
                    }
                    'work/processes/proc-123/workitemtypes/Custom.Task/fields' {
                        @(
                            [pscustomobject]@{ referenceName = 'System.Title' },
                            [pscustomobject]@{ referenceName = 'Custom.MyField' }
                        )
                        break
                    }
                    'work/processes/proc-123/workitemtypes/Microsoft.VSTS.WorkItemTypes.Bug/fields' {
                        @(
                            [pscustomobject]@{ referenceName = 'System.Title' },
                            [pscustomobject]@{ referenceName = 'Microsoft.VSTS.Common.Priority' }
                        )
                        break
                    }
                    'work/processes/proc-123/workitemtypes/*/rules' { @() ; break }
                    'work/processes/proc-123/workitemtypes/*/states' { @() ; break }
                    'work/processes/proc-123/workitemtypes/*/layout' { @{ sections = @() } ; break }
                    'work/processes/proc-123/behaviors' { @() ; break }
                    'work/processes/proc-123/fields' {
                        throw [System.Exception]::new('404: Not Found')
                    }
                    default {
                        throw "Unexpected endpoint in test: $Endpoint"
                    }
                }
            }
        }

        It 'exports with unique field counting and auto-resolution from WIT aggregation' {
            $dest = Join-Path -Path $TestDrive -ChildPath 'export1'
            New-Item -ItemType Directory -Path $dest -Force | Out-Null

            $file = Export-AzDOWorkItemProcess `
                -ProcessName 'MyInheritedProc' `
                -Destination $dest `
                -NoRetry `
                -CollectionUri 'https://example.visualstudio.com/' `
                -Pat 'x'
            $file | Should -Not -BeNullOrEmpty
            Test-Path $file.FullName | Should -BeTrue

            $json = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -AsHashtable
            $summary = $json['_exportSummary']

            # Validate statistics derived from unique WIT fields
            # (System.Title, Custom.MyField, Microsoft.VSTS.Common.Priority)
            $summary.statistics.totalFields | Should -Be 3
            $summary.statistics.systemFields | Should -Be 1
            $summary.statistics.standardFields | Should -Be 1
            $summary.statistics.customFields | Should -Be 1
            $summary.statistics.workItemTypes | Should -Be 2

            # Auto-resolution = (system + standard)/total = (2/3)*100 = 66.7
            [double]$summary.importGuidance.expectedAutoResolution | Should -Be 66.7

            # Intentionally not asserting mock invocation counts due to Pester v6 alpha behavior.
            # The content assertions above validate the call flow sufficiently for this unit test.
        }
    }

    Context 'Zero division guard when no fields are present' {
        BeforeAll {
            # Reset and re-mock with empty WIT fields and 404 process fields
            Mock -ModuleName AzDOCmd Invoke-AzDORestApiMethod -MockWith {
                param(
                    $Headers,
                    $CollectionUri,
                    $ApiVersion,
                    $Method,
                    $Project,
                    $Endpoint,
                    [switch] $NoRetry
                )

                $null = $Headers
                $null = $CollectionUri
                $null = $ApiVersion
                $null = $Method
                $null = $Project
                $null = $NoRetry

                switch -Wildcard ($Endpoint) {
                    'work/processes' { @([pscustomobject]@{ name = 'EmptyProc'; typeId = 'proc-999' }) }
                    'work/processes/proc-999/workitemtypes' { @([pscustomobject]@{ referenceName = 'Custom.Empty' }) }
                    'work/processes/proc-999/workitemtypes/*/fields' { @() }
                    'work/processes/proc-999/workitemtypes/*/rules' { @() }
                    'work/processes/proc-999/workitemtypes/*/states' { @() }
                    'work/processes/proc-999/workitemtypes/*/layout' { @{ sections = @() } }
                    'work/processes/proc-999/behaviors' { @() }
                    'work/processes/proc-999/fields' { throw [System.Exception]::new('404: Not Found') }
                    default { throw "Unexpected endpoint in test: $Endpoint" }
                }
            }
        }

        It 'sets totalFields to 0 and expectedAutoResolution to 0 when no fields' {
            $dest = Join-Path -Path $TestDrive -ChildPath 'export2'
            New-Item -ItemType Directory -Path $dest -Force | Out-Null

            $file = Export-AzDOWorkItemProcess `
                -ProcessName 'EmptyProc' `
                -Destination $dest `
                -NoRetry `
                -CollectionUri 'https://example.visualstudio.com/' `
                -Pat 'x'
            $file | Should -Not -BeNullOrEmpty

            $json = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -AsHashtable
            $summary = $json['_exportSummary']

            $summary.statistics.totalFields | Should -Be 0
            [double]$summary.importGuidance.expectedAutoResolution | Should -Be 0
        }
    }
}
