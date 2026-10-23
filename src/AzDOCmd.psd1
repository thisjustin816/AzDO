@{
    RootModule           = 'AzDOCmd.psm1'
    ModuleVersion        = '2.5.0'
    GUID                 = 'a145d090-e911-4298-8744-dd3b04b4d4e5'
    Author               = ''
    CompanyName          = ''
    Copyright            = ''
    Description          = 'A module for interacting with Azure DevOps.'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport    = @()
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    RequiredModules      = @('JBUtils')
    PrivateData          = @{
        PSData = @{
            Tags         = @(
                'PSEdition_Desktop', 'PSEdition_Core', 'Azure', 'AzureDevOps',
                'AzDO', 'AzurePipelines', 'AzPipelines'
            )
            ProjectUri   = ''
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ReleaseNotes = ''
            Prerelease   = ''
        }
    }
}
