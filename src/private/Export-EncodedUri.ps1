<#
.SYNOPSIS
Encodes a URI string to make it safe for use in API calls.

.DESCRIPTION
The `Export-EncodedUri` function takes a URI string as input and encodes it using the `System.Uri.EscapeDataString` method. 
This ensures that special characters in the URI are properly escaped, making the URI safe for use in web requests or API calls.

.PARAMETER Uri
The URI string to encode. This parameter is mandatory and accepts input from the pipeline.

.OUTPUTS
String
The encoded URI string.

.EXAMPLE
PS> Export-EncodedUri -Uri "https://example.com/path with spaces"
https%3A%2F%2Fexample.com%2Fpath%20with%20spaces

.EXAMPLE
PS> "https://example.com/path with spaces" | Export-EncodedUri
https%3A%2F%2Fexample.com%2Fpath%20with%20spaces

.NOTES
This function replaces backslashes (`\`) with forward slashes (`/`) before encoding the URI.
It is useful for ensuring compatibility with APIs that require properly encoded URIs.
#>
function Export-EncodedUri {
    [OutputType([String])]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [String]$Uri
    )

    process {
        [Uri]::EscapeDataString($Uri.Replace('\', '/'))
    }
}