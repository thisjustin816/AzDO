<#
.SYNOPSIS
Exports a work item process definition to a JSON file.

.DESCRIPTION
Exports a work item process definition to a JSON file. This can be used to backup process definitions
or prepare them for import into another organization. The exported file includes enhanced metadata
to improve import success rates and provides guidance on expected auto-resolution capabilities.

.PARAMETER ProcessName
The name of the work item process to export.

.PARAMETER Destination
The destination folder where the JSON file will be saved.

.PARAMETER NoRetry
A switch to disable the default retry mechanism for REST API calls.

.PARAMETER Pat
Personal access token with Process (read) permissions. Defaults to $env:SYSTEM_ACCESSTOKEN.

.PARAMETER CollectionUri
The collection URI of the Azure DevOps organization. Defaults to $env:SYSTEM_COLLECTIONURI.

.EXAMPLE
Export-AzDOWorkItemProcess -ProcessName "Agile" -Destination "C:/Temp"

.EXAMPLE
Export-AzDOWorkItemProcess -ProcessName "CustomProcess" -Destination ".\Exports" -NoRetry

.OUTPUTS
FileInfo. Returns the FileInfo object of the exported JSON file.

.NOTES
This function requires Process (read) permissions in the organization.

The exported JSON includes:
- Enhanced field metadata for import optimization
- Export summary with statistics
- Import guidance including expected auto-resolution rates
- Recommendations for using AutoResolveConflicts during import
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
        . "$PSScriptRoot/../../private/Clear-AzDOObjectOrgData.ps1"

        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.1'
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
        Write-Progress @progress -Status 'Getting process definition...'
        $processDefinition = Clear-AzDOObjectOrgData -InputObject $process

        Write-Progress @progress -Status 'Getting work item types...'
        $workItemTypes = Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method Get `
            -Endpoint "work/processes/$($process.typeId)/workitemtypes" `
            -NoRetry:$NoRetry

        $workItemTypesWIthDetails = @()
        $witTotal = $workItemTypes.Count
        $i = 0
        $workItemTypesWIthDetails += foreach ($wit in $workItemTypes) {
            $wit = Clear-AzDOObjectOrgData -InputObject $wit

            $i++
            $witIndex = $i
            $witName = $wit.referenceName

            $witWithContent = $wit
            foreach ($property in @('fields', 'rules', 'states', 'layout')) {
                $witWithContent | Add-Member -NotePropertyName $property -NotePropertyValue $null
            }

            $progress['Status'] = "Processing work item type '$witName' ($witIndex of $witTotal)"
            $progress['PercentComplete'] = ($witIndex / $witTotal) * 100
            Write-Progress @progress -CurrentOperation 'Fields'

            $witWithContent.fields = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Endpoint "work/processes/$($process.typeId)/workitemtypes/$witName/fields" `
                -NoRetry:$NoRetry | ForEach-Object {
                Clear-AzDOObjectOrgData -InputObject $_
            }

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

            # Microsoft Test work item types have read-only layouts
            if (-not $witName.StartsWith('Microsoft.VSTS.WorkItemTypes.Test')) {
                Write-Progress @progress -CurrentOperation 'Layout'
                $witWithContent.layout = Invoke-AzDORestApiMethod `
                    @script:AzApiHeaders `
                    -Method Get `
                    -Endpoint "work/processes/$($process.typeId)/workitemtypes/$witName/layout" `
                    -NoRetry:$NoRetry
            }

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

        $sanitizedBehaviors = foreach ($behavior in $processBehaviors) {
            Clear-AzDOObjectOrgData -InputObject $behavior
        }

        $processDefinition | Add-Member `
            -NotePropertyName behaviors `
            -NotePropertyValue $sanitizedBehaviors

        $progress['Status'] = 'Getting process fields...'
        Write-Progress @progress
        try {
            # Some inherited processes do not expose the process-level fields endpoint; use processDefinition.typeId for accuracy
            $processFields = Invoke-AzDORestApiMethod `
                @script:AzApiHeaders `
                -Method Get `
                -Endpoint "work/processes/$($processDefinition.typeId)/fields" `
                -NoRetry:$NoRetry
        }
        catch {
            if ($_.Exception.Message -match '404') {
                Write-Warning "Process fields endpoint not available for this process type. Continuing without process-level fields."
                $processFields = @()
            }
            else {
                throw
            }
        }

        # Enhance fields with classification metadata to improve import success rates
        $enhancedFields = foreach ($field in $processFields) {
            $cleanField = Clear-AzDOObjectOrgData -InputObject $field

            # Add field classification for better import handling
            $isSystemField = $field.referenceName -like 'System.*'
            $isStandardField = $field.referenceName -like 'Microsoft.VSTS.*'
            $isCustomField = $field.referenceName -like 'Custom.*'

            $cleanField | Add-Member -NotePropertyName '_exportMetadata' -NotePropertyValue @{
                isSystemField   = $isSystemField
                isStandardField = $isStandardField
                isCustomField   = $isCustomField
                fieldCategory   = if ($isSystemField) { 'System' }
                                 elseif ($isStandardField) { 'Standard' }
                                 elseif ($isCustomField) { 'Custom' }
                                 else { 'Unknown' }
                exportedAt      = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
            } -Force

            $cleanField
        }

        $processDefinition | Add-Member `
            -NotePropertyName fields `
            -NotePropertyValue $enhancedFields

        $progress['Status'] = 'Finalizing export...'
        Write-Progress @progress -Completed

        # Collect fields from work item types to handle inherited processes where process-level fields may be unavailable
        $allFields = @()
        foreach ($workItemType in $processDefinition.workItemTypes) {
            if ($workItemType.fields) {
                $allFields += $workItemType.fields
            }
        }

        # Build a unique set of fields by referenceName
        $uniqueFields = @()
        $seen = @{}
        foreach ($f in $allFields) {
            $ref = $f.referenceName
            if (-not $seen.ContainsKey($ref)) {
                $seen[$ref] = $true
                $uniqueFields += $f
            }
        }

        # Compute category counts from unique fields
        $systemFields   = $uniqueFields | Where-Object { $_.referenceName -like 'System.*' }
        $standardFields = $uniqueFields | Where-Object { $_.referenceName -like 'Microsoft.VSTS.*' }
        $customFields   = $uniqueFields | Where-Object { $_.referenceName -like 'Custom.*' }

        $systemFieldCount   = $systemFields.Count
        $standardFieldCount = $standardFields.Count
        $customFieldCount   = $customFields.Count
        $witCount           = $workItemTypesWIthDetails.Count
        $behaviorCount      = $sanitizedBehaviors.Count

        # Calculate auto-resolution percentage for import guidance with division-by-zero protection
        if ($uniqueFields.Count -gt 0) {
            $autoResolutionRate = [math]::Round((($systemFields.Count + $standardFields.Count) / $uniqueFields.Count) * 100, 1)
        }
        else {
            $autoResolutionRate = 0
        }

        $exportSummary = @{
            processName    = $ProcessName
            exportedAt     = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
            statistics     = @{
                workItemTypes  = $witCount
                totalFields    = $uniqueFields.Count
                systemFields   = $systemFieldCount
                standardFields = $standardFieldCount
                customFields   = $customFieldCount
                behaviors      = $behaviorCount
            }
            importGuidance = @{
                expectedAutoResolution        = $autoResolutionRate
                customFieldsRequiringCreation = $customFieldCount
                recommendation                = if ($customFieldCount -gt 0) {
                    "Use -AutoResolveConflicts switch during import for optimal results"
                }
                else {
                    "Standard import should work without conflicts"
                }
            }
        }

        $processDefinition | Add-Member `
            -NotePropertyName '_exportSummary' `
            -NotePropertyValue $exportSummary

        $outFileName = ($ProcessName -replace '[^\w\-\.]', '_').ToLower() + '.json'
        $outFileName = Join-Path -Path $Destination -ChildPath $outFileName
        $processDefinition |
            ConvertTo-Json -Depth 100 |
            Out-File -FilePath $outFileName -Encoding UTF8 -Force

        # Display export summary to user
        Write-Host "Successfully exported process '$ProcessName'" -ForegroundColor Green
        Write-Host "Export Summary:" -ForegroundColor Cyan
        Write-Host "  Work Item Types: $witCount" -ForegroundColor White
    Write-Host "  Total Fields: $($uniqueFields.Count)" -ForegroundColor White
        Write-Host "    - System Fields: $systemFieldCount" -ForegroundColor Gray
        Write-Host "    - Standard Fields: $standardFieldCount" -ForegroundColor Gray
        Write-Host "    - Custom Fields: $customFieldCount" -ForegroundColor Yellow
        Write-Host "  Behaviors: $behaviorCount" -ForegroundColor White
        Write-Host "  Expected Auto-Resolution Rate: $($exportSummary.importGuidance.expectedAutoResolution)%" `
            -ForegroundColor Green
        Write-Host "  Recommendation: $($exportSummary.importGuidance.recommendation)" -ForegroundColor Cyan
        Write-Host "  File: $outFileName" -ForegroundColor White

        Get-Item -Path $outFileName
    }
}
