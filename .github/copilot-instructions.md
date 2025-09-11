# Copilot Instructions for AzDOCmd

## Project Overview
AzDOCmd is a PowerShell module providing API wrappers for Azure DevOps. The module follows a **functional area organization** with standardized REST API patterns and comprehensive parameter handling.

## Architecture & Structure

### Module Organization
- **`src/AzDOCmd.psm1`**: Main module file that dot-sources all public functions (no logic, just imports)
- **`src/public/`**: Public functions organized by functional area:
  - `agents/` - Agent pool management
  - `info/` - Project and organization info
  - `packages/` - Package feed management  
  - `pipelines/` - Build/release pipeline operations
  - `repositories/` - Repository management
  - `utils/` - Utility functions
  - `work/` - Work item processes and management
- **`src/private/`**: Internal helper functions (e.g., `Get-AzDOApiProjectName.ps1`, `Clear-AzDOObjectOrgData.ps1`)

### Function Naming Convention
All functions follow PowerShell approved verbs: `Get-AzDO*`, `Set-AzDO*`, `New-AzDO*`, `Remove-AzDO*`, `Add-AzDO*`, `Export-AzDO*`, `Import-AzDO*`, etc.

## Critical Patterns

### Standard Function Template
Every Azure DevOps API function MUST follow this exact pattern:

```powershell
function Verb-AzDONoun {
    [CmdletBinding()]
    param (
        # Function-specific parameters first
        [Parameter(Position = 0)]
        [String]$SpecificParam,
        [Switch]$NoRetry,
        # Standard parameters (ALWAYS last in this exact order)
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [System.Object]$Project = $env:SYSTEM_TEAMPROJECT,
        [String]$CollectionUri = $env:SYSTEM_COLLECTIONURI,
        [String]$Pat = $env:SYSTEM_ACCESSTOKEN
    )

    begin {
        # Dot-source any required private functions FIRST
        . "$PSScriptRoot\..\..\private\HelperFunction.ps1"

        $script:AzApiHeaders = @{
            Headers       = Initialize-AzDORestApi -Pat $Pat
            CollectionUri = $CollectionUri
            ApiVersion    = '7.1'  # Use 7.1 for current functions, adjust as needed
        }
    }

    process {
        # Project parameter processing (for pipeline scenarios)
        . "$PSScriptRoot\..\..\private\Get-AzDOApiProjectName.ps1"
        $Project = $Project | Get-AzDOApiProjectName

        # API call using standard pattern
        Invoke-AzDORestApiMethod `
            @script:AzApiHeaders `
            -Method $Method `
            -Project $Project `
            -Endpoint $Endpoint `
            -NoRetry:$NoRetry
    }
}
```

**Note**: Some functions may have variations in parameter order based on their specific needs, but the standard parameters should always be last. Functions that don't use `$Project` may not need `Get-AzDOApiProjectName` processing.

### Key Implementation Rules
1. **Parameter Order**: Function-specific params first, then `[Switch]$NoRetry`, then the three standard params in exact order
2. **API Headers**: Always use `$script:AzApiHeaders` with `Initialize-AzDORestApi`
3. **Project Processing**: Always dot-source and use `Get-AzDOApiProjectName` for pipeline compatibility
4. **Splatting**: Use `@script:AzApiHeaders` splatting for `Invoke-AzDORestApiMethod`
5. **Comments**: Include comments to explain complex logic or API interactions. Don't just state what the code is doing.
6. **Outputs**: Only use return when necessary. I.e. prefer outputting objects directly rather than using return statements.
7. **Private Functions**: Private helper functions should be dot-sourced in the `begin` block of the public function that uses them. They should not be loaded in the main `.psm1` file.

### Complex Functions (Import/Export)
For complex operations like `Import-AzDOWorkItemProcess.ps1`:
- Use `[CmdletBinding(SupportsShouldProcess = $true)]` for destructive operations
- Implement `[Switch]$Force` parameters for overwriting existing resources  
- Use `Write-Progress` for long-running operations
- Handle API method patterns: POST for creation, PUT for updates with fallback logic
- Implement proper error handling with `ErrorAction Stop` for exception flow

## Development Workflow

### Building & Testing
```powershell
# Build and test (runs PSScriptAnalyzer, Pester tests)
.\build.ps1

# Module analysis with auto-fix
Invoke-PSModuleAnalyzer -Fix

# Publishing (with confirmation unless in GitHub Actions)
.\publish.ps1
```

### Testing Requirements
- Every function needs a corresponding `.Tests.ps1` file in the same directory
- Use Pester framework with standardized structure based on test type:

**Unit Tests** (for private functions and isolated testing):
```powershell
Describe 'Unit Tests' -Tag 'Unit' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../AzDOCmd.psm1" -Force

        # Dot source the function under test (for private functions)
        . "$PSScriptRoot/FunctionName.ps1"
    }
    # Test cases with mocking for dependencies
}
```

**Integration Tests** (for public functions with real API calls):
```powershell
Describe 'Integration Tests' -Tag 'Integration' {
    BeforeAll {
        Get-Module -Name AzDOCmd -All | Remove-Module -Force -ErrorAction SilentlyContinue
        Import-Module -Name "$PSScriptRoot/../../AzDOCmd.psm1" -Force
    }
    # Test cases with real environment dependencies
}
```

### Testing Best Practices
- **Private Functions**: Use unit tests with comprehensive mocking of dependencies like `Invoke-AzDORestApiMethod`
- **Mocking**: Always specify `-ModuleName AzDOCmd` when mocking functions to ensure proper scope
- **Coverage**: Include parameter validation, error handling, success paths, and edge cases
- **Assertions**: Use `Should -Invoke` to verify mock calls and `Should` operators for output validation

## Dependencies & Environment
- **Environment Variables**: Functions default to Azure DevOps pipeline variables (`SYSTEM_*`)
- **API Versions**: Use API version 7.1 for current development (updated from older 6.0 references)
- **Private Function Dependencies**: Always dot-source required private functions in the `begin` block

## Error Handling & Validation
- **Parameter Validation**: Use PowerShell parameter attributes and validation
- **API Error Handling**: Use `ErrorAction Stop` for critical operations that should halt execution
- **User Feedback**: Use `Write-Warning` for non-fatal issues, `Write-Progress` for long operations
- **Null/Empty Checks**: Always validate required objects and parameters before processing

## Special Considerations

### Work Item Processes
The `work/` area handles complex Azure DevOps process import/export. The `Export-AzDOWorkItemProcess` and `Import-AzDOWorkItemProcess` functions are designed to facilitate cross-organization migrations.

- **Export Sanitization**: The export function uses a recursive helper (`Clear-AzDOObjectOrgData`) to remove organization-specific properties (like URLs and IDs) from the exported JSON, making it portable.
- **Cross-Org Import Strategy**: The import function is designed to handle sanitized JSON files.
  - It filters out system work item types (`System.*`, `Microsoft.VSTS.*`) which cannot be modified.
  - It skips organization-specific custom behaviors that are identified by a GUID pattern (`Custom.<GUID>`).
- **Custom Field Namespacing**: Fields are prefixed with the process name (e.g., `ProcessName.MyField`).
- **API Method Patterns**: POST is used for creation, with a fallback to PUT for updates if `-Force` is specified.
- **Summary Reporting**: The import function provides a detailed summary report at the end of execution, categorizing failed and skipped items to provide clear, actionable feedback instead of noisy inline warnings.
- **Force Parameter Logic**: Controls overwriting existing components across all process elements.
- **Required Private Functions**: Both functions require proper dot-sourcing of private helpers:
  - `Clear-AzDOObjectOrgData.ps1` (both Export and Import)
  - `Import-AzDOProcessField.ps1` (Import only)
  - `Import-AzDOBehavior.ps1` (Import only)

### Common Implementation Patterns
- **Dot-Sourcing**: Always use `"$PSScriptRoot\..\..\private\FunctionName.ps1"` syntax with double quotes for proper path resolution
- **Progress Reporting**: Use `Write-Progress` with consistent Activity/Status/PercentComplete patterns for long operations
- **Object Processing**: Use `foreach` constructs with proper variable scoping for collection processing
- **Return Handling**: Prefer direct output over `return` statements; use `return` only for early exits

### Pipeline Integration  
Functions support Azure DevOps pipeline contexts through:
- Default parameter values from environment variables
- `Project` parameter accepting objects from pipeline (processed via `Get-AzDOApiProjectName`)
- `ValueFromPipelineByPropertyName` for seamless pipeline integration

## Debugging & Troubleshooting

### Common Issues & Solutions
1. **Function Not Found Errors**: Usually indicates missing dot-sourcing of private functions in the `begin` block
2. **Variable Not Defined**: Check for proper variable initialization before use (e.g., `$processDefinition` vs `$process`)
3. **API Authentication Failures**: Verify `Initialize-AzDORestApi` is called with valid PAT in the `begin` block
4. **Path Resolution Issues**: Always use `"$PSScriptRoot\..\..\private\FunctionName.ps1"` with double quotes for dot-sourcing

### Testing Troubleshooting
1. **Mock Not Working**: Ensure `-ModuleName AzDOCmd` is specified for all Mock commands
2. **Should -Invoke Failures**: Verify mock function names match exactly, including case sensitivity
3. **Module Import Issues**: Use full path `"$PSScriptRoot/../AzDOCmd.psm1"` or `"$PSScriptRoot/../../AzDOCmd.psm1"` depending on test location

### Validation Checklist
Before committing new functions:
- [ ] Private functions are dot-sourced in `begin` block
- [ ] API version is set to 7.1 (current standard)
- [ ] Standard parameter order is followed
- [ ] Proper error handling with `ErrorAction Stop` where needed
- [ ] Test file exists with matching name pattern
- [ ] Help comments are comprehensive for wiki generation

## File Organization Rules
- One function per `.ps1` file with matching filename
- Functions in appropriate `public/` subdirectory by functional area
- Helper functions in `private/` directory
- No `Export-ModuleMember` statements (automatic discovery)
- Comprehensive help comments for wiki auto-generation
