<#
.SYNOPSIS
Gets a release pipeline definition object from Azure Pipelines.

.DESCRIPTION
Gets a release pipeline definition object from Azure Pipelines using a project and name filter.

.PARAMETER Name
A filter to search for release pipeline names.

.PARAMETER Id
The release pipeline ID to get.

.PARAMETER Project
Project that the release pipelines reside in.

.PARAMETER CollectionUri
The project collection URL (https://dev.azure.com/[orgranization]).

.PARAMETER Pat
Personal access token authorized to administer releases. Defaults to $env:SYSTEM_ACCESSTOKEN for use in Azure
Pipelines.

.EXAMPLE
Get-AzDOReleasePipeline -Project Packages -Name ReleasePipeline*

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/release/definitions/get

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/release/pipelines/list

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>

function Get-AzDOReleasePipeline {
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [String[]]$Name,
        [Parameter(ParameterSetName = 'Id', Position = 0)]
        [Int[]]$Id,
        [Switch]$NoRetry,
        [String[]]$Project = $env:SYSTEM_TEAMPROJECT,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [string]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        . "$PSScriptRoot/../../private/Add-AzDOProject.ps1"

        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.2-preview.4'
        }
    }

    process {
        if ($Id) {
            foreach ($projectName in $Project) {
                $pipeline = Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Get `
                    -SubDomain vsrm `
                    -Project $projectName `
                    -Endpoint 'release/definitions' `
                    -Params @(
                        "definitionIds=$($Id -join ',')"
                        'propertyFilters=variables,environments'
                     ) `
                    -NoRetry:$NoRetry `
                    -WhatIf:$false
                if ($pipeline) {
                    $pipeline
                }
                else {
                    Write-Warning -Message "Pipeline $Id not found in $projectName."
                }
            }
        }
        elseif ($Name) {
            foreach ($filter in $Name) {
                foreach ($projectName in $Project) {
                    $pipelineResponse = Invoke-AzDORestApiMethod `
                        @script:AzApiHeaders `
                        -Method Get `
                        -SubDomain vsrm `
                        -Project $projectName `
                        -Endpoint 'release/definitions' `
                        -Params @(
                            "searchText=$filter"
                            'propertyFilters=variables,environments'
                         ) `
                        -NoRetry:$NoRetry `
                        -WhatIf:$false
                    if ($pipelineResponse) {
                        $pipelineResponse | Add-AzDOProject -NoRetry:$NoRetry -CollectionUri $CollectionUri -Pat $Pat
                    }
                    else {
                        Write-Warning -Message "No pipelines found matching '$filter' in $projectName."
                    }
                }
            }
        }
        else {
            foreach ($projectName in $Project) {
                $pipelineResponse = Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Get `
                    -SubDomain vsrm `
                    -Project $projectName `
                    -Endpoint 'release/definitions' `
                    -Params 'propertyFilters=variables,environments' `
                    -NoRetry:$NoRetry `
                    -WhatIf:$false
                if ($pipelineResponse) {
                    $pipelineResponse | Add-AzDOProject -NoRetry:$NoRetry -CollectionUri $CollectionUri -Pat $Pat
                }
                else {
                    Write-Warning -Message "No pipelines found in $projectName."
                }
            }
        }
    }
}
