<#
.SYNOPSIS
Gets a build definition object from Azure Pipelines.

.DESCRIPTION
Gets a build definition object from Azure Pipelines using a project and name filter.

.PARAMETER Name
A filter to search for pipeline names.

.PARAMETER Id
The pipeline ID to get.

.PARAMETER Project
Project that the pipelines reside in.

.PARAMETER CollectionUri
The project collection URL (https://dev.azure.com/[orgranization]).

.PARAMETER Pat
Personal access token authorized to administer builds. Defaults to $env:SYSTEM_ACCESSTOKEN for use in Azure
Pipelines.

.EXAMPLE
Get-AzDOPipeline -Project Packages -Name AzurePipeline*

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/pipelines/pipelines/get

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/pipelines/pipelines/list

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzRestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>

function Get-AzDOPipeline {
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
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzRestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '6.1'
        }
    }

    process {
        if ($Id) {
            foreach ($projectName in $Project) {
                $pipeline = Invoke-AzRestApiMethod `
                    @script:AzApiHeaders `
                    -Method Get `
                    -Project $projectName `
                    -Endpoint 'build/definitions' `
                    -Params "definitionIds=$($Id -join ',')" `
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
                    $pipelineResponse = Invoke-AzRestApiMethod `
                        @script:AzApiHeaders `
                        -Method Get `
                        -Project $projectName `
                        -Endpoint 'build/definitions' `
                        -Params "name=$filter" `
                        -NoRetry:$NoRetry `
                        -WhatIf:$false
                    if ($pipelineResponse) {
                        $pipelineResponse
                    }
                    else {
                        Write-Warning -Message "No pipelines found matching '$filter' in $projectName."
                    }
                }
            }
        }
        else {
            foreach ($projectName in $Project) {
                $pipelineResponse = Invoke-AzRestApiMethod `
                    @script:AzApiHeaders `
                    -Method Get `
                    -Project $projectName `
                    -Endpoint 'build/definitions' `
                    -NoRetry:$NoRetry `
                    -WhatIf:$false
                if ($pipelineResponse) {
                    $pipelineResponse
                }
                else {
                    Write-Warning -Message "No pipelines found in $projectName."
                }
            }
        }
    }
}
