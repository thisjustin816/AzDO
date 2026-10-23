<#
.SYNOPSIS
Internal: returns Azure DevOps relation names keyed by their friendly names.
#>
function Get-AzDOWorkItemRelationTypeMap {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param ()

    @{
        'Parent'      = 'System.LinkTypes.Hierarchy-Reverse'
        'Child'       = 'System.LinkTypes.Hierarchy-Forward'
        'Successor'   = 'System.LinkTypes.Dependency-Forward'
        'Predecessor' = 'System.LinkTypes.Dependency-Reverse'
        'Related'     = 'System.LinkTypes.Related'
    }
}
