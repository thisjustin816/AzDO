<#
.SYNOPSIS
Formats a work item object for display.

.DESCRIPTION
This function takes a work item object and returns a custom object with the following properties:
- Id
- Type
- Title
- State
- Project
- AreaPath
- IterationPath
- AssignedTo
- Url

.PARAMETER WorkItem
The work item object to format.

.EXAMPLE
Get-AzDOWorkItem -Id 12345 | Format-AzDOWorkItem

.NOTES
N/A
#>
function Format-AzDOWorkItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateScript({
                $_.PSObject.Properties.Name -contains 'id' -and
                $_.PSObject.Properties.Name -contains 'fields' -and
                $_.PSObject.Properties.Name -contains '_links'
            })]
        [System.Object]$WorkItem,
        [Switch]$Expand
    )

    process {
        try {
            $basicObject = @{
                Id    = $WorkItem.id
                Type  = $WorkItem.fields.'System.WorkItemType'
                Title = $WorkItem.fields.'System.Title'
            }
            $url = @{
                Url = $WorkItem._links.html.href
            }
            $finalObject = $basicObject
            if ($Expand) {
                $expandedProperties = @{
                    State         = $WorkItem.fields.'System.State'
                    Project       = $WorkItem.fields.'System.TeamProject'
                    AreaPath      = $WorkItem.fields.'System.AreaPath'
                    IterationPath = $WorkItem.fields.'System.IterationPath'
                    AssignedTo    = $WorkItem.fields.'System.AssignedTo'
                }
                foreach ($key in $expandedProperties.Keys) {
                    $finalObject[$key] = $expandedProperties[$key]
                }
            }
            foreach ($key in $url.Keys) {
                $finalObject[$key] = $url[$key]
            }
            [PSCustomObject]$finalObject
        }
        catch {
            Write-Error -Message "Failed to format work item: $($_.Exception.Message)"
        }
    }
}
