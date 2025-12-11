<#
.SYNOPSIS
Gets the process ID from a project, or validates a provided process ID.

.DESCRIPTION
Returns a process ID either from the specified ProcessId parameter or by deriving it from a Project object.
If neither is provided, throws an error.

.PARAMETER ProcessId
The ID of the process. If provided, this is returned as-is.

.PARAMETER Project
The project object from which to derive the process ID.

.PARAMETER CollectionUri
The URI of the Azure DevOps org (e.g. https://dev.azure.com/myorg). Defaults to the SYSTEM_COLLECTIONURI environment
variable.

.PARAMETER Pat
Azure DevOps personal authentication token. Defaults to the SYSTEM_ACCESSTOKEN environment variable.

.PARAMETER NoRetry
Disables automatic retry logic for API calls.

.EXAMPLE
$processId = Get-AzDOProjectProcessId -ProcessId '6b724f1d-ef1f-4f0d-9d3a-2c4f5f3e6a1b'

.EXAMPLE
$processId = Get-AzDOProjectProcessId -Project $project -CollectionUri 'https://dev.azure.com/myorg'

.NOTES
At least one of ProcessId or Project must be provided.
#>
function Get-AzDOProjectProcessId {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [String]$ProcessId,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]$Project = $env:SYSTEM_TEAMPROJECT,

        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,

        [String]$Pat = $env:SYSTEM_ACCESSTOKEN,

        [Switch]$NoRetry
    )

    process {
        if ($ProcessId) {
            return $ProcessId
        }

        # If ProcessId not specified, try to get it from the project
        if ($Project) {
            . "$PSScriptRoot/Get-AzDOApiProjectName.ps1"
            $projectName = $Project | Get-AzDOApiProjectName

            $projectDetails = Get-AzDOProject `
                -Name $projectName `
                -CollectionUri $CollectionUri `
                -Pat $Pat `
                -NoRetry:$NoRetry

            return $projectDetails.capabilities.processTemplate.templateTypeId
        }

        throw 'ProcessId is required. Specify it directly or provide a Project to derive it from.'
    }
}
