<#
.SYNOPSIS
Escapes a value in an Azure Pipelines agent logging command.
#>
function ConvertTo-AzPipelinesLoggingValue {
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [AllowNull()]
        [AllowEmptyString()]
        [String]$Value
    )

    $escaped = $Value.Replace('%', '%AZP25')
    $escaped = $escaped.Replace(';', '%3B').Replace(']', '%5D')
    $escaped.Replace("`r", '%0D').Replace("`n", '%0A')
}
