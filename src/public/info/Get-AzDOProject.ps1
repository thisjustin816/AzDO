
<#
.SYNOPSIS
Gets information for an Azure DevOps project.

.DESCRIPTION
Gets information for an Azure DevOps project.

.PARAMETER Name
Name of the project.

.PARAMETER CollectionUri
https://dev.azure.com/[organization]

.PARAMETER Pat
A personal access token authorized as a reader for the collection.

.EXAMPLE
Get-AzDOProject -Name MyProject

.LINK
https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/get

.NOTES
N/A
#>
function Get-AzDOProject {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [String[]]$Name,
        [Switch]$NoRetry,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '6.1'
        }

        $restParams = @{
            Method  = 'Get'
            Params  = @('includeCapabilities=true')
            NoRetry = $NoRetry
        }
    }

    process {
        if ($Name) {
            foreach ($ref in $Name) {
                Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    @restParams `
                    -Endpoint "projects/$ref"
            }
        }
        else {
            Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                @restParams `
                -Endpoint 'projects'
        }
    }
}
