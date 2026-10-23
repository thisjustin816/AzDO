<#
.SYNOPSIS
Sets a non-secret variable for subsequent Azure Pipelines tasks.

.DESCRIPTION
Writes an agent logging command only when AGENT_JOBNAME is set. Escapes logging-command
delimiters and line breaks. The current process environment is unchanged. PATH is protected
unless Force is supplied. Use this command for non-secret values only.

.PARAMETER Name
Variable name. Accepts pipeline objects with a Name property.

.PARAMETER Value
Variable value. Null and empty values clear the pipeline variable.

.PARAMETER PassThru
Returns an object containing the original Name and Value after writing the command.

.PARAMETER Force
Allows setting PATH. Does not bypass WhatIf or Confirm.

.OUTPUTS
System.Management.Automation.PSCustomObject. Returned only with PassThru.

.EXAMPLE
Set-AzPipelinesVariable -Name PackageVersion -Value '1.2.3'

.LINK
https://learn.microsoft.com/azure/devops/pipelines/scripts/logging-commands
#>
function Set-AzPipelinesVariable {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [String]$Value,

        [Switch]$PassThru,

        [Switch]$Force
    )

    process {
        if ($env:AGENT_JOBNAME) {
            if ($Name -eq 'PATH' -and -not $Force) {
                Write-Warning -Message "$Name is not able to be overwritten in the pipeline. Nothing was set."
            }
            elseif ($PSCmdlet.ShouldProcess($Name, 'Set Azure Pipelines variable')) {
                $escapedName = ConvertTo-AzPipelinesLoggingValue -Value $Name
                $escapedValue = ConvertTo-AzPipelinesLoggingValue -Value $Value
                Write-Host -Object "##vso[task.setvariable variable=$escapedName]$escapedValue"

                if ($PassThru) {
                    [PSCustomObject]@{
                        Name  = $Name
                        Value = $Value
                    }
                }
            }
        }
    }
}
