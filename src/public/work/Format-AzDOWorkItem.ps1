<#
.SYNOPSIS
Formats a work item object for display.

.DESCRIPTION
This function takes a work item object and returns a custom object with the following properties:
- Id
- Type
- Title
- State
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
            $_.PSObject.Properties.Name -contains 'url'
        })]
        [System.Object]$WorkItem
    )

    process {
        try {
            [PSCustomObject]@{
                Id          = $WorkItem.id
                Type        = $WorkItem.fields.'System.WorkItemType'
                Title       = $WorkItem.fields.'System.Title'
                State       = $WorkItem.fields.'System.State'
                AssignedTo  = $WorkItem.fields.'System.AssignedTo'
                Url         = $WorkItem._links.html.href
            }
        }
        catch {
            Write-Error -Message "Failed to format work item: $($_.Exception.Message)"
        }
    }
}
