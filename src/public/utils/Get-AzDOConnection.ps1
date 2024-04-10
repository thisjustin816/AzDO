function Get-AzDOConnection {
    [CmdletBinding()]
    param ()

    [PSCustomObject]@{
        CollectionURI = $env:SYSTEM_COLLECTIONURI
        Project       = $env:SYSTEM_TEAMPROJECT
        Pat           = $env:SYSTEM_ACCESSTOKEN
    }
}