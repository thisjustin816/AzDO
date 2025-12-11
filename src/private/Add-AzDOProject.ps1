<#
.SYNOPSIS
Adds project metadata to an Azure DevOps API response object.

.DESCRIPTION
Parses the URL property from an Azure DevOps API response object to extract the project reference, retrieves the full
project details, and attaches them as a 'project' property.

.PARAMETER InputObject
An API response object.

.PARAMETER NoRetry
Disables automatic retry logic for API calls.

.PARAMETER CollectionUri
The URI of the Azure DevOps org (e.g. https://dev.azure.com/myorg). Defaults to the SYSTEM_COLLECTIONURI environment
variable.

.PARAMETER Pat
Azure DevOps personal authentication token. Defaults to the SYSTEM_ACCESSTOKEN environment variable.

.EXAMPLE
$pipeline | Add-AzDOProject

.NOTES
N/A
#>
function Add-AzDOProject {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [System.Object]$InputObject,
        [Switch]$NoRetry,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    process {
        $url = $InputObject.PSObject.Properties |
            Where-Object -FilterScript { $_.MemberType -eq 'NoteProperty' -and $_.Name -match 'url' } |
            Select-Object -ExpandProperty Value

        $urlArray = $url.Split('/')
        $projectReference = $urlArray[$urlArray.IndexOf('_apis') - 1]
        $project = Get-AzDOProject -Name $projectReference -NoRetry:$NoRetry -CollectionUri $CollectionUri -Pat $Pat
        if ($project) {
            $InputObject | Add-Member -MemberType NoteProperty -Name project -Value $project
        }
        $InputObject
    }
}