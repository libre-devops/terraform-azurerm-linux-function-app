#Requires -Version 7.2
<#
.SYNOPSIS
    Sorts variable and output blocks, formats the Terraform, and regenerates the terraform-docs
    section of the README from HEADER.md.

.DESCRIPTION
    A thin wrapper over the LibreDevOpsHelpers module, so every module repository maintains its
    docs the same way. Installs the module from PSGallery if it is not already available.

.PARAMETER CodePath
    Module root to process. Defaults to the current directory.

.PARAMETER ReadmeHeaderFile
    Hand-authored README header written above the terraform-docs markers. Defaults to HEADER.md.

.PARAMETER IncludeExamples
    Also format and sort the stacks under examples/.

.EXAMPLE
    ./Sort-LdoTerraform.ps1 -IncludeExamples
#>
[CmdletBinding()]
param(
    [string]$CodePath = '.',
    [string]$ReadmeHeaderFile = 'HEADER.md',
    [switch]$IncludeExamples
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name LibreDevOpsHelpers)) {
    Install-Module LibreDevOpsHelpers -Scope CurrentUser -Force -AllowClobber
}
Import-Module LibreDevOpsHelpers -Force

# Sort variables/outputs and format, then regenerate the README docs section from HEADER.md.
Format-LdoTerraformCode -CodePath $CodePath
Update-LdoReadmeWithTerraformDocs -CodePath $CodePath -ReadmeHeaderFile $ReadmeHeaderFile

if ($IncludeExamples) {
    $examplesRoot = Join-Path $CodePath 'examples'
    if (Test-Path $examplesRoot) {
        Get-ChildItem -Path $examplesRoot -Directory | ForEach-Object {
            Format-LdoTerraformCode -CodePath $_.FullName

            # Regenerate the example README too when it carries its own header file, so each
            # example folder gets the same terraform-docs treatment as the module root.
            $exampleHeader = Join-Path $_.FullName $ReadmeHeaderFile
            if (Test-Path $exampleHeader -PathType Leaf) {
                Update-LdoReadmeWithTerraformDocs -CodePath $_.FullName -ReadmeHeaderFile $ReadmeHeaderFile
            }
            else {
                Write-Verbose "No $ReadmeHeaderFile in $($_.FullName); skipping README generation for this example."
            }
        }
    }
}
