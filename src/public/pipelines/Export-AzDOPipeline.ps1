<#
.SYNOPSIS
Exports a pipeline definition's json file.

.DESCRIPTION
Exports a pipeline definition's json file.

.PARAMETER PipelineDefinition
A pipeline definition passed via the pipeline from Get-BuildPipeline.

.PARAMETER Destination
Destination folder of the json backup files.

.PARAMETER Pat
Personal access token authorized to administer pipelines and releases. Defaults to $env:SYSTEM_ACCESSTOKEN for use
in Azure Pipelines.

.EXAMPLE
Get-AzDOPipeline -Project Packages -Name AzurePipeline* | Export-AzDOPipeline

.NOTES
The Cmdlet will work as-is in a UI Pipeline with the default $Pat parameter as long as OAUTH access has been
enabled for the pipeline/job. If using a YAML build, the system.accesstoken variable needs to be explicitly
mapped to the steps environment like the following example:

steps:
- powershell: Invoke-WebRequest -Uri $Uri -Headers ( Initialize-AzDORestApi )
  env:
    SYSTEM_ACCESSTOKEN: $(system.accesstoken)
#>

function Export-AzDOPipeline {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [System.Object[]]$PipelineDefinition,
        [string]$Destination = 'azure-pipelines',
        [Switch]$NoRetry,
        [String[]]$Project = $env:SYSTEM_TEAMPROJECT,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [string]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.2-preview.4'
        }

        $null = New-Item -Path $Destination -ItemType Directory -Force
    }

    process {
        foreach ($definition in $PipelineDefinition) {
            $outFileName = "$Destination/$($definition.name).json"
            Invoke-WebRequest -Uri $definition.url -Headers $script:AzApiHeaders['Headers'] -UseBasicParsing |
                Select-Object -ExpandProperty Content |
                Out-File -FilePath $outFileName -Encoding UTF8 -Force
            Get-Item -Path $outFileName
        }
    }
}