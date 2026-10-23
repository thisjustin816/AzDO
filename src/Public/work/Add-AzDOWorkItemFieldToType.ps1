<#
.SYNOPSIS
Adds a field to a work item type in a process.

.DESCRIPTION
Adds an existing field to a specific work item type within a process. The field must already exist in the process.

.PARAMETER ProcessId
The ID of the process containing the work item type.

.PARAMETER WorkItemTypeRefName
The reference name of the work item type (e.g., 'Microsoft.VSTS.WorkItemTypes.Task').

.PARAMETER FieldRefName
The reference name of the field to add (e.g., 'Custom.ReflectedWorkItemId').

.PARAMETER GroupId
Optional Group ID to add the field to (e.g., 'Details', 'Planning').

.PARAMETER NoRetry
Disables automatic retry logic for API calls.

.PARAMETER Project
The project object representing the Azure DevOps project.

.PARAMETER CollectionUri
The URI of the Azure DevOps org (e.g. https://dev.azure.com/myorg). Defaults to the SYSTEM_COLLECTIONURI environment
variable.

.PARAMETER Pat
Azure DevOps personal authentication token. Defaults to the SYSTEM_ACCESSTOKEN environment variable.

.EXAMPLE
Add-AzDOWorkItemFieldToType `
    -ProcessId '6b724f1d-ef1f-4f0d-9d3a-2c4f5f3e6a1b' `
    -WorkItemTypeRefName 'Microsoft.VSTS.WorkItemTypes.Task' `
    -FieldRefName 'Custom.ReflectedWorkItemId' `
    -GroupId 'Details'

.NOTES
The field must already exist in the specified process.

.LINK
https://learn.microsoft.com/en-us/rest/api/azure/devops/processes/fields/add
#>
function Add-AzDOWorkItemFieldToType {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [String]$ProcessId,

        [Parameter(Mandatory = $true)]
        [String]$WorkItemTypeRefName,

        [Parameter(Mandatory = $true)]
        [String]$FieldRefName,

        [String]$GroupId,

        [Switch]$NoRetry,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]$Project = $env:SYSTEM_TEAMPROJECT,

        [Parameter()]
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,

        [Parameter()]
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion = "7.1-preview.2"
        }
    }

    process {
        $ProcessId = Get-AzDOProjectProcessId `
            -ProcessId $ProcessId `
            -Project $Project `
            -CollectionUri $CollectionUri `
            -Pat $Pat `
            -NoRetry:$NoRetry

        $body = @{
            referenceName = $FieldRefName
        }
        if ($GroupId) {
            $body.group = $GroupId
        }

        try {
            Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Post `
                -SubDomain 'dev' `
                -Endpoint "work/processes/$ProcessId/workItemTypes/$WorkItemTypeRefName/fields" `
                -Body ( $body | ConvertTo-Json -Depth 10 -Compress ) `
                -NoRetry:$NoRetry `
                -ErrorAction Stop
        }
        catch {
            if ($_.Exception.Message -like '*TF402571*' -or $_.Exception.Message -like '*already contains*') {
                Write-Warning "Field '$FieldRefName' already exists in work item type '$WorkItemTypeRefName' of process '$ProcessId'."
                return
            }
            else {
                throw $_
            }
        }
    }
}
