<#
.SYNOPSIS
Recursively removes organization-specific properties from a PowerShell object.

.DESCRIPTION
This helper function takes a PSObject and recursively removes properties that are specific to an
Azure DevOps organization, such as internal IDs, URLs, and other metadata. This sanitizes the
object, making it suitable for cross-organization migration by preventing import failures caused
by organization-specific data.

The function creates a deep copy of the input object to ensure the original object remains
unmodified. It processes nested objects and collections, ensuring all parts of the data
structure are cleaned.

.PARAMETER InputObject
The PowerShell object (PSObject) to sanitize. This can be a single object or a collection.

.PARAMETER PropertiesToRemove
An array of property names to be removed from the object and any nested objects. Defaults to a
pre-defined list of common organization-specific properties.

.EXAMPLE
$cleanProcess = Clear-AzDOObjectOrgData -InputObject $processDefinition
This example removes the default set of organization-specific properties from the
$processDefinition object.

.NOTES
This is a private helper function and is not intended for direct use. It is dot-sourced by
public functions that require data sanitization.
#>
function Clear-AzDOObjectOrgData {
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$InputObject,
        [String[]]$PropertiesToRemove = @('id', 'url', '_links', 'customization', 'inherits', 'rank')
    )

    if (-not $InputObject) {
        return $null
    }

    $cleanObject = $InputObject.PSObject.Copy()

    foreach ($prop in $PropertiesToRemove) {
        if ($cleanObject.PSObject.Properties[$prop]) {
            $cleanObject.PSObject.Properties.Remove($prop)
        }
    }

    foreach ($property in $cleanObject.PSObject.Properties) {
        $value = $property.Value
        if ($value -is [PSObject]) {
            $property.Value = Clear-AzDOObjectOrgData -InputObject $value -PropertiesToRemove $PropertiesToRemove
        }
        elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [String]) {
            $collection = @()
            foreach ($item in $value) {
                if ($item -is [PSObject]) {
                    $collection += Clear-AzDOObjectOrgData -InputObject $item -PropertiesToRemove $PropertiesToRemove
                }
                else {
                    $collection += $item
                }
            }
            $property.Value = $collection
        }
    }

    return $cleanObject
}
