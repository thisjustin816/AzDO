<#
.SYNOPSIS
Exports a work item process definition to a JSON file.

.DESCRIPTION
Exports a work item process definition to a JSON file. This can be used to backup process definitions
or prepare them for import into another organization.

.PARAMETER ProcessName
The name of the work item process to export.

.PARAMETER Destination
The destination folder where the JSON file will be saved.

.PARAMETER Pat
Personal access token with Process (read) permissions. Defaults to $env:SYSTEM_ACCESSTOKEN.

.PARAMETER CollectionUri
The collection URI of the Azure DevOps organization. Defaults to $env:SYSTEM_COLLECTIONURI.

.EXAMPLE
Export-AzDOWorkItemProcess -ProcessName "Agile" -Destination "C:\Temp"

.NOTES
This function requires Process (read) permissions in the organization.
#>
function Export-AzDOWorkItemProcess {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$ProcessName,
        [String]$Destination = $PWD,
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

        $null = New-Item -Path $Destination -ItemType Directory -Force
    }

    process {
        $process = Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method Get `
            -Endpoint 'work/processes' `
            -NoRetry:$NoRetry |
            Where-Object { $_.name -eq $ProcessName }

        if (-not $process) {
            Write-Warning "Process '$ProcessName' not found."
        }
        else {
            $processDefinition = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Endpoint "work/processes/$($process.typeId)" `
                -NoRetry:$NoRetry

            $outFileName = "$Destination/$($ProcessName -replace '[^\w\-\.]', '_').json"
            $processDefinition |
                ConvertTo-Json -Depth 100 |
                Out-File -FilePath $outFileName -Encoding UTF8 -Force

            Get-Item -Path $outFileName
        }
    }
}
