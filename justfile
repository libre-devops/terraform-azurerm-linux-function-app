# Libre DevOps Terraform module task runner. Run `just` to list recipes.
#
# Install just with either:
#   brew install just
#   uv tool add rust-just     # then call recipes as: uv run just <recipe>
#
# The recipes wrap the LibreDevOpsHelpers engine functions in PowerShell so local development
# mirrors the libre-devops/terraform-azure action. plan/apply/destroy use the remote azurerm
# backend and perform the same storage firewall "open before, close after" dance the action does,
# reading the state coordinates from the TFSTATE_* environment variables published by the tenant
# bootstrap:
#   export TFSTATE_RESOURCE_GROUP=...  TFSTATE_STORAGE_ACCOUNT=...  TFSTATE_BLOB_CONTAINER=...
# Authenticate first with `az login`. The workspace selects the environment (default dev, or set
# TF_WORKSPACE).

set shell := ["pwsh", "-NoProfile", "-Command"]

workspace := env_var_or_default("TF_WORKSPACE", "dev")

# Tag prefix. Empty for Terraform modules so tags are plain semver (1.2.3), which the Terraform
# Registry requires. GitHub Action repos set this to "v".
tag_prefix := ""

# List available recipes.
default:
    just --list

# Install or force-update LibreDevOpsHelpers (the engine the recipes wrap) from PSGallery.
update-ldo-pwsh:
    if (Get-Module -ListAvailable LibreDevOpsHelpers) { Update-Module LibreDevOpsHelpers -Force; Write-Host 'Updated LibreDevOpsHelpers to the latest from PSGallery.' } else { Install-Module LibreDevOpsHelpers -Scope CurrentUser -Force -AllowClobber; Write-Host 'Installed LibreDevOpsHelpers from PSGallery.' }

# Format every Terraform file in place.
fmt:
    terraform fmt -recursive

# Offline quality gates for the module and its examples: format check, validate, tflint, trivy.
# (Conftest naming checks need a plan, so they run in plan/apply/e2e, not here.)
validate:
    #!/usr/bin/env pwsh
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module LibreDevOpsHelpers -Force
    Set-LdoLogFormat -Format Text
    Clear-LdoFinding
    foreach ($path in @('.', 'examples/minimal', 'examples/complete')) {
        Write-Host "== $path =="
        Invoke-LdoTerraformFmtCheck -CodePath $path
        terraform -chdir=$path init -backend=false -input=false | Out-Null
        Invoke-LdoTerraformValidate -CodePath $path
        Invoke-LdoTfLint -CodePath $path
        Invoke-LdoTrivy -CodePath $path
    }
    Show-LdoFindingsSummary

# Trivy config scan over the module and its examples (no init or cloud needed). Gates on
# HIGH,CRITICAL like the action; a subset of `validate` for when you only want the security scan.
scan:
    #!/usr/bin/env pwsh
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module LibreDevOpsHelpers -Force
    Set-LdoLogFormat -Format Text
    Clear-LdoFinding
    foreach ($path in @('.', 'examples/minimal', 'examples/complete')) {
        Write-Host "== $path =="
        Invoke-LdoTrivy -CodePath $path
    }
    Show-LdoFindingsSummary

# Run PSScriptAnalyzer over the repo's PowerShell scripts using the repo settings. Fails on Error.
pwsh-analyze:
    #!/usr/bin/env pwsh
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) { Install-Module PSScriptAnalyzer -MinimumVersion 1.21.0 -Force -Scope CurrentUser }
    $scripts = Get-ChildItem -Path . -Filter *.ps1 -File
    if (-not $scripts) { Write-Host 'No PowerShell scripts to analyze.'; return }
    $results = $scripts | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings ./PSScriptAnalyzerSettings.psd1 }
    if (@($results | Where-Object { $_.Severity -eq 'Error' }).Count -gt 0) {
        $results | Format-Table -AutoSize | Out-String | Write-Host
        throw 'PSScriptAnalyzer found errors.'
    }
    Write-Host 'PSScriptAnalyzer: clean.'

# Run the native terraform tests (plan-time, mocked provider, no cloud credentials).
test:
    terraform init -backend=false -input=false | Out-Null
    terraform test

# Sort variables/outputs, format, and regenerate the README from HEADER.md.
docs:
    ./Sort-LdoTerraform.ps1 -IncludeExamples

# Plan an example against the remote state. Example: just plan complete
plan stack="complete":
    just _run plan {{ stack }} {{ workspace }}

# Apply an example (plans first). Example: just apply complete
apply stack="complete":
    just _run apply {{ stack }} {{ workspace }}

# Destroy an example. Example: just destroy complete
destroy stack="complete":
    just _run destroy {{ stack }} {{ workspace }}

# Apply an example then always destroy it in the same run (destroy even if apply fails), so
# nothing is left running to incur Azure cost. Mirrors the CI self-test. Defaults to the minimal
# example. Example: just e2e complete
e2e stack="minimal":
    #!/usr/bin/env pwsh
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module LibreDevOpsHelpers -Force
    Set-LdoLogFormat -Format Text
    Set-LdoTraceContext -Generate
    Clear-LdoFinding

    # Conftest the plan against the naming policies, mirroring the action. Uses a local policy dir
    # from LDO_CONFTEST_POLICIES when set, otherwise shallow-clones the public custom-policies repo.
    function Invoke-LdoConftestPlan {
        param([Parameter(Mandatory)][string]$CodePath)
        if (-not (Get-Command conftest -ErrorAction SilentlyContinue)) {
            Write-LdoLog -Level WARN -Message 'conftest not installed; skipping the naming policy check (brew install conftest, or Install-LdoConftest).'
            return
        }
        $planJson = Convert-LdoTerraformPlanToJson -CodePath $CodePath -PassThru
        $pol = $env:LDO_CONFTEST_POLICIES
        $cfClone = $null
        try {
            if (-not ($pol -and (Test-Path $pol))) {
                $cfClone = Join-Path ([System.IO.Path]::GetTempPath()) ("ldo-conftest-policies-" + [guid]::NewGuid())
                git clone --depth 1 --branch main https://github.com/libre-devops/custom-policies.git $cfClone 2>&1 | Out-Null
                $pol = Join-Path $cfClone 'policies'
            }
            Invoke-LdoConftest -PlanJsonPath $planJson -PolicyPath $pol
        }
        finally {
            if ($cfClone -and (Test-Path $cfClone)) { Remove-Item $cfClone -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    $rg = $env:TFSTATE_RESOURCE_GROUP
    $sa = $env:TFSTATE_STORAGE_ACCOUNT
    $cn = $env:TFSTATE_BLOB_CONTAINER
    if (-not ($rg -and $sa -and $cn)) {
        throw 'Set TFSTATE_RESOURCE_GROUP, TFSTATE_STORAGE_ACCOUNT and TFSTATE_BLOB_CONTAINER (the values published by the tenant bootstrap).'
    }

    $path = 'examples/{{ stack }}'
    $key = 'terraform-azurerm-linux-function-app-{{ stack }}.tfstate'
    $added = $false
    try {
        Add-LdoStorageCurrentIpRule -ResourceGroup $rg -StorageAccountName $sa
        $added = $true

        Invoke-LdoTerraformFmtCheck -CodePath $path
        Invoke-LdoTerraformInit -CodePath $path -InitArgs @(
            '-reconfigure',
            "-backend-config=resource_group_name=$rg",
            "-backend-config=storage_account_name=$sa",
            "-backend-config=container_name=$cn",
            "-backend-config=key=$key"
        )
        Invoke-LdoTerraformWorkspaceSelect -CodePath $path -WorkspaceName '{{ workspace }}'
        Invoke-LdoTerraformValidate -CodePath $path
        Invoke-LdoTfLint -CodePath $path
        Invoke-LdoTrivy -CodePath $path

        try {
            Invoke-LdoTerraformPlan -CodePath $path
            Invoke-LdoConftestPlan -CodePath $path
            Show-LdoFindingsSummary
            Invoke-LdoTerraformApply -CodePath $path -SkipApprove
        }
        finally {
            # Always tear the stack down, even when the apply failed, so live resources never linger.
            Invoke-LdoTerraformPlanDestroy -CodePath $path
            Invoke-LdoTerraformDestroy -CodePath $path -SkipApprove
        }
    }
    finally {
        if ($added) { Remove-LdoStorageCurrentIpRule -ResourceGroup $rg -StorageAccountName $sa }
    }

# Internal: run one Terraform operation against the remote backend with the storage firewall
# opened for this machine and always closed again afterwards, mirroring the action's engine.
_run op stack ws:
    #!/usr/bin/env pwsh
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module LibreDevOpsHelpers -Force
    Set-LdoLogFormat -Format Text
    Set-LdoTraceContext -Generate
    Clear-LdoFinding

    # Conftest the plan against the naming policies, mirroring the action. Uses a local policy dir
    # from LDO_CONFTEST_POLICIES when set, otherwise shallow-clones the public custom-policies repo.
    function Invoke-LdoConftestPlan {
        param([Parameter(Mandatory)][string]$CodePath)
        if (-not (Get-Command conftest -ErrorAction SilentlyContinue)) {
            Write-LdoLog -Level WARN -Message 'conftest not installed; skipping the naming policy check (brew install conftest, or Install-LdoConftest).'
            return
        }
        $planJson = Convert-LdoTerraformPlanToJson -CodePath $CodePath -PassThru
        $pol = $env:LDO_CONFTEST_POLICIES
        $cfClone = $null
        try {
            if (-not ($pol -and (Test-Path $pol))) {
                $cfClone = Join-Path ([System.IO.Path]::GetTempPath()) ("ldo-conftest-policies-" + [guid]::NewGuid())
                git clone --depth 1 --branch main https://github.com/libre-devops/custom-policies.git $cfClone 2>&1 | Out-Null
                $pol = Join-Path $cfClone 'policies'
            }
            Invoke-LdoConftest -PlanJsonPath $planJson -PolicyPath $pol
        }
        finally {
            if ($cfClone -and (Test-Path $cfClone)) { Remove-Item $cfClone -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    $rg = $env:TFSTATE_RESOURCE_GROUP
    $sa = $env:TFSTATE_STORAGE_ACCOUNT
    $cn = $env:TFSTATE_BLOB_CONTAINER
    if (-not ($rg -and $sa -and $cn)) {
        throw 'Set TFSTATE_RESOURCE_GROUP, TFSTATE_STORAGE_ACCOUNT and TFSTATE_BLOB_CONTAINER (the values published by the tenant bootstrap).'
    }

    $path = 'examples/{{ stack }}'
    $key = 'terraform-azurerm-linux-function-app-{{ stack }}.tfstate'
    $added = $false
    try {
        Add-LdoStorageCurrentIpRule -ResourceGroup $rg -StorageAccountName $sa
        $added = $true

        Invoke-LdoTerraformFmtCheck -CodePath $path
        Invoke-LdoTerraformInit -CodePath $path -InitArgs @(
            '-reconfigure',
            "-backend-config=resource_group_name=$rg",
            "-backend-config=storage_account_name=$sa",
            "-backend-config=container_name=$cn",
            "-backend-config=key=$key"
        )
        Invoke-LdoTerraformWorkspaceSelect -CodePath $path -WorkspaceName '{{ ws }}'
        Invoke-LdoTerraformValidate -CodePath $path

        # Lint/scan gates run for plan and apply, not for a destroy teardown (matching the action).
        if ('{{ op }}' -ne 'destroy') {
            Invoke-LdoTfLint -CodePath $path
            Invoke-LdoTrivy -CodePath $path
        }

        switch ('{{ op }}') {
            'destroy' {
                Invoke-LdoTerraformPlanDestroy -CodePath $path
                Invoke-LdoTerraformDestroy -CodePath $path -SkipApprove
            }
            default {
                Invoke-LdoTerraformPlan -CodePath $path
                Invoke-LdoConftestPlan -CodePath $path
                Show-LdoFindingsSummary
                if ('{{ op }}' -eq 'apply') {
                    Invoke-LdoTerraformApply -CodePath $path -SkipApprove
                }
            }
        }
    }
    finally {
        if ($added) { Remove-LdoStorageCurrentIpRule -ResourceGroup $rg -StorageAccountName $sa }
    }

# --- Resource group management locks (operational, like the firewall dance) ---------------
# The management lock is applied operationally, not by Terraform, so a ReadOnly lock never races
# resources being deployed into the group. These wrap the AzureLock helpers; `az login` first.

# Add a management lock to a resource group. Example: just azure-rg-lock rg-ldo-uks-prd-001 ReadOnly
azure-rg-lock rg level="CanNotDelete":
    Import-Module LibreDevOpsHelpers -Force; Add-LdoResourceGroupLock -ResourceGroup '{{ rg }}' -LockName 'lock-{{ rg }}' -LockLevel '{{ level }}'

# Remove all management locks from a resource group. Example: just azure-remove-lock rg-ldo-uks-prd-001
azure-remove-lock rg:
    Import-Module LibreDevOpsHelpers -Force; Remove-LdoResourceGroupLock -ResourceGroup '{{ rg }}'

# --- Release management -------------------------------------------------------------------
# Tags are plain semver (1.2.3) so the Terraform Registry picks them up. Pass a bare version like
# 1.2.3; the tag_prefix variable (empty here) is applied automatically. Action repos set
# tag_prefix to "v" and use force-push-tag to move a moving major alias.

# Create and push an annotated tag. Example: just tag 1.2.3
tag version:
    git tag -a '{{ tag_prefix }}{{ version }}' -m 'Release {{ tag_prefix }}{{ version }}'
    git push origin '{{ tag_prefix }}{{ version }}'

# Bump the latest semver tag and push the new tag. level = patch (default), minor, or major.
increment-tag level="patch":
    $p = '{{ tag_prefix }}'; $re = '^' + [regex]::Escape($p) + '\d+\.\d+\.\d+$'; $tags = @(git tag --list | Where-Object { $_ -match $re }); $cur = if ($tags.Count -eq 0) { [version]'0.0.0' } else { ($tags | ForEach-Object { [version]($_.Substring($p.Length)) } | Sort-Object)[-1] }; $next = switch ('{{ level }}') { 'major' { "$($cur.Major + 1).0.0" } 'minor' { "$($cur.Major).$($cur.Minor + 1).0" } 'patch' { "$($cur.Major).$($cur.Minor).$($cur.Build + 1)" } default { throw 'level must be patch, minor, or major' } }; $tag = "$p$next"; git tag -a $tag -m "Release $tag"; git push origin $tag; Write-Host "Tagged and pushed $tag"

# Create a GitHub release from an existing tag, with auto-generated notes. Example: just release 1.2.3
release version:
    gh release create '{{ tag_prefix }}{{ version }}' --title '{{ tag_prefix }}{{ version }}' --generate-notes

# Tag a specific version and release it. Example: just tag-and-release 1.2.3
tag-and-release version:
    git tag -a '{{ tag_prefix }}{{ version }}' -m 'Release {{ tag_prefix }}{{ version }}'
    git push origin '{{ tag_prefix }}{{ version }}'
    gh release create '{{ tag_prefix }}{{ version }}' --title '{{ tag_prefix }}{{ version }}' --generate-notes

# Bump the latest tag, push it, and create a release. level = patch (default), minor, or major.
increment-release level="patch":
    $p = '{{ tag_prefix }}'; $re = '^' + [regex]::Escape($p) + '\d+\.\d+\.\d+$'; $tags = @(git tag --list | Where-Object { $_ -match $re }); $cur = if ($tags.Count -eq 0) { [version]'0.0.0' } else { ($tags | ForEach-Object { [version]($_.Substring($p.Length)) } | Sort-Object)[-1] }; $next = switch ('{{ level }}') { 'major' { "$($cur.Major + 1).0.0" } 'minor' { "$($cur.Major).$($cur.Minor + 1).0" } 'patch' { "$($cur.Major).$($cur.Minor).$($cur.Build + 1)" } default { throw 'level must be patch, minor, or major' } }; $tag = "$p$next"; git tag -a $tag -m "Release $tag"; git push origin $tag; gh release create $tag --title $tag --generate-notes; Write-Host "Released $tag"

# Bump, tag, and release in one step (same as increment-release). Example: just increment-tag-and-release minor
increment-tag-and-release level="patch":
    just increment-release {{ level }}

# Force-update a tag to a ref and push it (literal tag), for example a moving major alias.
force-push-tag tag ref="HEAD":
    git tag -f '{{ tag }}' '{{ ref }}'
    git push -f origin '{{ tag }}'
    @echo "Force-pushed {{ tag }} to {{ ref }}"
