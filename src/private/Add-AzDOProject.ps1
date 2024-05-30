<#
.SYNOPSIS
${1:Short description}

.DESCRIPTION
${2:Long description}

.PARAMETER InputObject
${3:Parameter description}

.PARAMETER NoRetry
${4:Parameter description}

.PARAMETER CollectionUri
${5:Parameter description}

.PARAMETER Pat
${6:Parameter description}

.EXAMPLE
${7:An example}

.NOTES
${8:General notes}
#>
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