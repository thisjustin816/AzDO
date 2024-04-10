<#
.SYNOPSIS
${1:Short description}

.DESCRIPTION
${2:Long description}

.EXAMPLE
${3:An example}

.NOTES
${4:General notes}
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