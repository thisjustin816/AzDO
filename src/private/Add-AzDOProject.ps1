function Add-AzDOProject {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [System.Object]$InputObject,
        [Switch]$NoRetry,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [string]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    process {
        $url = $InputObject.PSObject.Properties |
            Where-Object -FilterScript { $_.MemberType -eq 'NoteProperty' -and $_.Name -match 'url' } |
            Select-Object -ExpandProperty Value

        $urlArray = $url.Split('/')
        $projectReference = $urlArray[$urlArray.IndexOf('_apis') - 1]
        $project = Get-AzDOProject -Name $projectReference -NoRetry:$NoRetry -CollectionUri $CollectionUri -Pat $Pat
        if ($project) {
            $InputObject | Add-Member -MemberType NoteProperty -Name project -Value $project
        }
        $InputObject
    }
}