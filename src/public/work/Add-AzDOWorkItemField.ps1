<#
.SYNOPSIS
Adds a custom field to a work item process.

.DESCRIPTION
Creates a custom field in te specified Azure DevOps process. This is required for migration scenarios where the target
process needs fields that track migration metadata like ReflectedWorkItemId.

.PARAMETER ProcessId
The ID of the process to add the field to.

.PARAMETER FieldName
The reference name of the field (e.g., 'Custom.ReflectedWorkItemId')

.PARAMETER Description
Optional description of the field.

.PARAMETER AllowGroups
WHether the field allows groups (for identity fields).

.PARAMETER IsIdentity
Whether this is an identity field.

.PARAMETER NoRetry
Disables automatic retry logic for API calls.

.PARAMETER CollectionUri
The URI of the Azure DevOps org (e.g. https://dev.azure.com/myorg). Defaults to the SYSTEM_COLLECTIONURI environment
variable.

.PARAMETER Pat
Azure DevOps personal authentication token. Defaults to the SYSTEM_ACCESSTOKEN environment variable.

.EXAMPLE
Add-AzDOWorkItemField `
    -ProcessId '6b724f1d-ef1f-4f0d-9d3a-2c4f5f3e6a1b' `
    -FieldName 'Custom.ReflectedWorkItemId' `
    -DisplayName 'Reflected Work Item ID' `
    -FieldType 'String' `
    -Description 'Tracks the original work item ID from the source system.'

.EXAMPLE
Get-AzDOProject -Name 'MyProject' | Add-AzDOWorkItemField `
    -FieldName 'Custom.MigrationDate' `
    -DisplayName 'Migration Date' `
    -FieldType 'DateTime' `
    -Description 'Tracks the date of migration.'

.NOTES
Requires permissions to modify the specified process in Azure DevOps.

.LINK
https://learn.microsoft.com/en-us/rest/api/devops/processes/fields/create
#>
function Add-AzDOWorkItemField {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [String]$ProcessId,

        [Parameter(Mandatory = $true)]
        [String]$FieldName,

        [Parameter(Mandatory = $true)]
        [String]$DisplayName,

        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'string',
            'integer',
            'double',
            'dateTime',
            'plainText',
            'html',
            'treePath',
            'history',
            'guid',
            'boolean',
            'identity',
            'picklistString',
            'picklistInteger',
            'picklistDouble'
        )]
        [String]$FieldType,

        [String]$Description = '',

        [Bool]$AllowGroups = $false,

        [Bool]$IsIdentity = $false,

        [Switch]$NoRetry,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]$Project = $env:SYSTEM_TEAMPROJECT,

        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,

        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.1-preview.2'
        }
    }

    process {
        # Get ProcessId if not specified
        $ProcessId = Get-AzDOProjectProcessId `
            -ProcessId $ProcessId `
            -Project $Project `
            -CollectionUri $CollectionUri `
            -Pat $Pat `
            -NoRetry:$NoRetry

        $body = @{
            name          = $DisplayName
            referenceName = $FieldName
            type          = $FieldType
            description   = $Description
            allowGroups   = $AllowGroups
            isIdentity    = $IsIdentity
        } | ConvertTo-Json -Depth 10 -Compress

        try {
            Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Post `
                -SubDomain 'dev' `
                -Endpoint "work/processes/$ProcessId/fields" `
                -Body $body `
                -NoRetry:$NoRetry `
                -ErrorAction Stop
        }
        catch {
            if ($_.Exception.Message -like '*TF402571*' -or $_.Exception.Message -like '*already exists*') {
                Write-Warning "Fields '$FieldName' already exists in process '$ProcessId'."

                # Try to get and return the existing field
                Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Get `
                    -SubDomain 'dev' `
                    -Endpoint "work/processes/$ProcessId/fields" `
                    -NoRetry:$NoRetry |
                    Select-Object -ExpandProperty value |
                    Where-Object { $_.referenceName -eq $FieldName }
            }
            else {
                throw $_
            }
        }
    }
}