<#
.SYNOPSIS
Gets the environment variables being used to connect to Azure DevOps.

.DESCRIPTION
Gets the environment variables being used to connect to Azure DevOps.

.EXAMPLE
Get-AzDOConnection

.NOTES
N/A
#>
function Get-AzDOConnection {
    [CmdletBinding()]
    param ()

    [PSCustomObject]@{
        CollectionURI = $env:SYSTEM_COLLECTIONURI
        Project       = $env:SYSTEM_TEAMPROJECT
        Pat           = $env:SYSTEM_ACCESSTOKEN
    }
}