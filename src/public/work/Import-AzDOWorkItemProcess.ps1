<#
.SYNOPSIS
Imports a work item process definition from a JSON file.

.DESCRIPTION
Imports a work item process definition from a JSON file. This can be used to restore process backups
or import processes from another organization.

.PARAMETER Path
The path to the JSON file containing the process definition.

.PARAMETER Pat
Personal access token with Process (manage) permissions. Defaults to $env:SYSTEM_ACCESSTOKEN.

.PARAMETER CollectionUri
The collection URI of the Azure DevOps organization. Defaults to $env:SYSTEM_COLLECTIONURI.

.PARAMETER Force
If specified, will overwrite an existing process with the same name.

.EXAMPLE
Import-AzDOWorkItemProcess -Path "C:\Temp\Agile.json"

.NOTES
This function requires Process (manage) permissions in the organization.
#>
function Import-AzDOWorkItemProcess {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Path,
        [Switch]$Force,
        [Switch]$NoRetry,
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
        $processDefinition = Get-Content -Path $Path -Raw | ConvertFrom-Json -ErrorAction Stop

        $existingProcess = Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method Get `
            -Endpoint "work/processes" `
            -NoRetry:$NoRetry |
            Where-Object { $_.name -eq $processDefinition.name }

        if ($existingProcess) {
            $shouldProcessMessage = "Process '$($processDefinition.name)' already exists. Would you like to update it?"
            if ($Force -or $PSCmdlet.ShouldContinue($shouldProcessMessage, "Confirm process update")) {
                if ($PSCmdlet.ShouldProcess($processDefinition.name, "Update process")) {
                    Invoke-AzDORestApiMethod `
                        @script:AzApiHeaders `
                        -Method Put `
                        -Endpoint "work/processes/$($existingProcess.typeId)" `
                        -Body ($processDefinition | ConvertTo-Json -Depth 100 -Compress) `
                        -NoRetry:$NoRetry
                }
            }
        }
        else {
            if ($PSCmdlet.ShouldProcess($processDefinition.name, "Create process")) {
                Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Post `
                    -Endpoint "work/processes" `
                    -Body ($processDefinition | ConvertTo-Json -Depth 100 -Compress) `
                    -NoRetry:$NoRetry
            }
        }
    }
}
