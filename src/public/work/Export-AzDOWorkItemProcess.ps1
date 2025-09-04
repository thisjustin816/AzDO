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
            return
        }

        $progress = @{
            Activity = "Exporting process '$ProcessName'"
        }
        Write-Progress @progress -Status "Getting process definition..."
        $processDefinition = Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method Get `
            -Endpoint "work/processes/$($process.typeId)" `
            -NoRetry:$NoRetry

        Write-Progress @progress -Status "Getting work item types..."
        $workItemTypes = Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method Get `
            -Endpoint "work/processes/$($process.typeId)/workitemtypes" `
            -NoRetry:$NoRetry

        $workItemTypesWIthDetails = @()
        $witTotal = $workItemTypes.Count
        $workItemTypesWIthDetails += foreach ($wit in $workItemTypes) {
            $witIndex = $workItemTypes.IndexOf($wit) + 1
            $witName = $wit.referenceName

            $witWithContent = $wit
            foreach ($property in @('fields', 'rules', 'states', 'behaviors', 'layout')) {
                $witWithContent | Add-Member -NotePropertyName $property -NotePropertyValue $null
            }

            $progress['Status'] = "Processing work item type '$witName' ($witIndex of $witTotal)"
            $progress['PercentComplete'] = ($witCurrent / $witTotal) * 100
            Write-Progress @progress -CurrentOperation 'Fields'

            $witWithContent.fields = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Endpoint "work/processes/$($process.typeId)/workitemtypes/$witName/fields" `
                -NoRetry:$NoRetry

            Write-Progress @progress -CurrentOperation 'Rules'
            $witWithContent.rules = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Endpoint "work/processes/$($process.typeId)/workitemtypes/$witName/rules" `
                -NoRetry:$NoRetry

            Write-Progress @progress -CurrentOperation 'States'
            $witWithContent.states = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Endpoint "work/processes/$($process.typeId)/workitemtypes/$witName/states" `
                -NoRetry:$NoRetry

            Write-Progress @progress -CurrentOperation 'Behaviors'
            $witWithContent.behaviors = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Endpoint "work/processes/$($process.typeId)/workitemtypes/$witName/behaviors" `
                -NoRetry:$NoRetry

            Write-Progress @progress -CurrentOperation 'Layout'
            $witWithContent.layout = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Endpoint "work/processes/$($process.typeId)/workitemtypes/$witName/layout" `
                -NoRetry:$NoRetry

            Write-Progress @progress -Completed
            $witWithContent
        }

        $processDefinition | Add-Member `
            -NotePropertyName workItemTypes `
            -NotePropertyValue $workItemTypesWIthDetails

        $progress['Status'] = 'Getting process behaviors...'
        Write-Progress @progress
        $processBehaviors = Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method Get `
            -Endpoint "work/processes/$($process.typeId)/behaviors" `
            -NoRetry:$NoRetry

        $processDefinition | Add-Member `
            -NotePropertyName behaviors `
            -NotePropertyValue $processBehaviors

        $progress['Status'] = 'Getting process fields...'
        Write-Progress @progress
        $processFields = Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method Get `
            -Endpoint "work/processes/$($process.typeId)/fields" `
            -NoRetry:$NoRetry

        $processDefinition | Add-Member `
            -NotePropertyName fields `
            -NotePropertyValue $processFields

        Write-Progress @progress -Completed

        $outFileName = ($ProcessName -replace '[^\w\-\.]', '_').ToLower() + '.json'
        $outFileName = Join-Path -Path $Destination -ChildPath $outFileName
        $processDefinition |
            ConvertTo-Json -Depth 100 |
            Out-File -FilePath $outFileName -Encoding UTF8 -Force

        Get-Item -Path $outFileName
    }
}
