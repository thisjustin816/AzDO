<#
.SYNOPSIS
Standardizes project parameters when using the pipeline to pass Azure DevOps API objects.

.DESCRIPTION
Standardizes project parameters when using the pipeline to pass Azure DevOps API objects.

.PARAMETER Project
Either the name, ID, or object of an Azure DevOps project.

.EXAMPLE
. .\Get-AzDOApiProjectName.ps1; $Project = $Project | Get-AzDOApiProjectName

.NOTES
N/A
#>
function Get-AzDOApiProjectName {
    [CmdletBinding()]
    [OutputType([String])]
    [OutputType([System.Object[]])]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [System.Object[]]$Project
    )

    process {
        if (
            $Project -and
            $Project[0] -isnot [String]
        ) {
            foreach ($object in $Project) {
                if ($object.name) {
                    $object.name
                }
                else {
                    $object.id
                }
            }
        }
        else {
            $Project
        }
    }
}