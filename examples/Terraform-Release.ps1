param(
    [string]$VariablesInFile = "./variables.tf",
    [string]$VariablesOutFile = "./variables.tf",
    [string]$OutputsInFile = "./outputs.tf",
    [string]$OutputsOutFile = "./outputs.tf",
    [string]$GitTag = "2.0.1",
    [string]$GitCommitMessage = "Update code",
    [bool]$SortInputs = $true,
    [bool]$SortOutputs = $true,
    [bool]$GitRelease = $true,
    [bool]$FormatTerraform = $true,
    [bool]$GenerateNewReadme = $true
)

$CurrentDirectory = (Get-Location).Path
$ErrorOccurred = $false

function Format-Terraform {
    try {
        $terraformPath = Get-Command terraform -ErrorAction Stop
        Write-Host "Success: Terraform found at: $($terraformPath.Source)" -ForegroundColor Green
        terraform fmt -recursive
        Write-Host "Success: Terraform formatted using terraform fmt" -ForegroundColor Green

    }
    catch {
        Write-Error "Error: Terraform is not installed or not in PATH, or terraform fmt failed due to syntax rror. Exiting."
        exit 1
    }
}

function Git-Release {
    param (
        [string]$GitTag,
        [string]$GitCommitMessage
    )

    try {
        $gitPath = Get-Command git -ErrorAction Stop
        Write-Host "Success: Git found at: $($gitPath.Source)" -ForegroundColor Green
        Write-Information "Info: Attemting git release"
        git add --all
        git commit -m "${GitCommitMessage}"
        git push
        git tag $GitTag --force
        git push --tags --force
    }
    catch {
        Write-Error "Error: Git is not installed or not in PATH, or git release failed due to syntax rror. Exiting."
        exit 1
    }
}

function Read-TerraformFile {
    param (
        [string]$Filename
    )

    if (Test-Path $Filename) {
        try {
            return Get-Content $Filename -Raw
        }
        catch {
            Write-Error "Error: Error reading file '$Filename': $_"
            $Global:ErrorOccurred = $true
            return $null
        }
    }
    else {
        Write-Error "File not found: $Filename"
        $Global:ErrorOccurred = $true
        return $null
    }
}

function Write-TerraformFile {
    param (
        [string]$Filename,
        [string]$FileContent
    )

    if ($null -ne $FileContent) {
        try {
            $FileContent | Set-Content $Filename
        }
        catch {
            Write-Error "Error: Error writing to file '$Filename': $_"
            $Global:ErrorOccurred = $true
        }
    }
    else {
        Write-Error "Error: No content to write to $Filename"
        $Global:ErrorOccurred = $true
    }
}

function Sort-TerraformOutputs {
    param (
        [string]$OutputsContent
    )

    try {
        $pattern = 'output\s+"[^"]+"\s+\{[\s\S]*?\n\}'
        $outputs = Select-String -Pattern $pattern -InputObject $OutputsContent -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value }
        return ($outputs | Sort-Object { [regex]::Match($_, 'output\s+"([^"]+)"').Groups[1].Value }) -join "`n`n"
    }
    catch {
        Write-Error "Error: Error sorting Terraform outputs: $_"
        $Global:ErrorOccurred = $true
        return $null
    }
}

function Sort-TerraformVariables {
    param (
        [string]$VariablesContent
    )

    try {
        $pattern = 'variable\s+"[^"]+"\s+\{[\s\S]*?\n\}'
        $variables = Select-String -Pattern $pattern -InputObject $VariablesContent -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_. Value }
        return ($variables | Sort-Object { [regex]::Match($_, 'variable\s+"([^"]+)"').Groups[1].Value }) -join "`n`n"
    }
    catch {
        Write-Error "Error: Error sorting Terraform variables: $_"
        $Global:ErrorOccurred = $true
        return $null
    }
}

function Update-ReadmeWithTerraformDocs {

    try {
        $terraformDocsPath = Get-Command terraform-docs -ErrorAction Stop
        Write-Host "Success: Terraform-docs found at: $($terraformDocsPath.Source)" -ForegroundColor Green
    }
    catch {
        Write-Error "Error: Terraform-docs is not installed or not in PATH, Skipping README generation."
    }


    $buildFile = ""
    if (Test-Path "./build.tf") {
        $buildFile = "./build.tf"
        Write-Host "Success: ${buildFile} found" -ForegroundColor Green
    } elseif (Test-Path "./main.tf") {
        $buildFile = "./main.tf"
        Write-Host "Success: ${buildFile} found" -ForegroundColor Green
    }

    if ($buildFile -ne "") {
        Set-Content "README.md" -Value '```hcl'
        Get-Content $buildFile | Add-Content "README.md"
        Add-Content "README.md" -Value '```'

        try {
            $terraformDocs = terraform-docs markdown .
            $terraformDocs | Add-Content "README.md"
        } catch {
            Write-Error "Error: Failed to generate or append terraform-docs markdown. Make sure terraform-docs is installed and in PATH."
        }
    } else {
        Write-Warning "Warning: Not a build directory, no build.tf or main.tf found"
    }
}


if ($FormatTerraform) {
    Format-Terraform
}

if ($SortInputs) {
    $VariablesContent = Read-TerraformFile -Filename $VariablesInFile
    if ($VariablesContent) {
        $SortedVariablesContent = Sort-TerraformVariables -VariablesContent $VariablesContent
        if ($SortedVariablesContent) {
            Write-TerraformFile -Filename $VariablesOutFile -FileContent $SortedVariablesContent
            Write-Host "Success: Sorted Terraform variables written to $VariablesOutFile" -ForegroundColor Green
        }
    }
}

if ($SortOutputs) {
    $OutputsContent = Read-TerraformFile -Filename $OutputsInFile
    if ($OutputsContent) {
        $SortedOutputsContent = Sort-TerraformOutputs -OutputsContent $OutputsContent
        if ($SortedOutputsContent) {
            Write-TerraformFile -Filename $OutputsOutFile -FileContent $SortedOutputsContent
            Write-Host "Success: Sorted Terraform outputs written to $OutputsOutFile" -ForegroundColor Green
        }
    }
}

if ($GenerateNewReadme) {
    Update-ReadmeWithTerraformDocs
}

if ($GitRelease) {
    Git-Release -GitTag "${GitTag}" -GitCommitMessage "${GitCommitMessage}"
}

if ($ErrorOccurred) {
    Write-Error "Error: The script completed with errors. Check the error messages above."
}
else {
    Write-Host "Success: The script completed successfully without errors." -ForegroundColor Green
}
