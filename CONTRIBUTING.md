# Contributing to Libre DevOps repositories

Your contributions mean a lot to us, and we welcome the community at every opportunity, whether
you are reporting an issue, reviewing code, proposing a fix, suggesting a feature, or interested
in becoming a maintainer.

## Development happens on GitHub

We use GitHub to host the code, track issues and feature requests, and review pull requests.
The most effective way to propose a change is a pull request following the
[GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow).

## Workflow

1. Fork the repository and branch from `main`.
2. Make your change, keeping it consistent with the
   [Libre DevOps standards](https://libredevops.org/docs/documents).
3. Verify your Terraform with `just validate` (format check, validate, tflint, and a `trivy config`
   scan), or `just scan` for the Trivy scan on its own. See "Security scanning and exceptions" below.
   The engine that the action runs is `Invoke-LdoTerraform.ps1`, which wraps this lifecycle using the
   [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers) module.
4. For Terraform module repositories, run `just docs` (`Sort-LdoTerraform.ps1`) to sort variables and
   outputs, format, and regenerate the README from `HEADER.md`. See "Sorting and docs style" below.
5. Keep PowerShell clean: PSScriptAnalyzer and the Pester tests under `Tests/` must pass.
6. Follow the naming convention `terraform-${provider}-${purpose}` for module repositories, and
   the [Azure naming convention](https://libredevops.org/docs/documents/azure-naming-convention)
   for resources.

## Security scanning and exceptions (Trivy)

The `trivy config` scan gates on HIGH and CRITICAL findings (these fail the build). MEDIUM, LOW, and
informational findings are reported for awareness but do not fail. Run `just scan` for the scan on
its own, or `just validate` for the full offline gates.

A finding may only be waived with a real, defensible reason, never to silence something that should
be fixed. Record every waiver in two places, kept in sync:

- `.trivyignore.yaml` at the module root, the machine-applied source of truth, with the `id`,
  optional `paths` to scope the waiver, and a `statement` recording why; and
- the "Security scan exceptions" table in the README, so the reason is auditable.

Where a finding is out of the module's scope, point the justification at the Libre DevOps module that
does address it (for example the private-endpoint module). Both the file and the table are reviewed
in the pull request.

## Sorting and docs style

Resources live in `main.tf`. Keep `variables.tf` and `outputs.tf` declarations sorted alphabetically
by name, one blank line between blocks, and put any comment describing a variable or output directly
above its block (the comment travels with the block when it is sorted). Give every variable a `type`
and a `description`.

Do not hand-edit the generated parts of a README. Run `just docs` (which calls
`Sort-LdoTerraform.ps1 -IncludeExamples`) to sort the variables and outputs, format the Terraform,
and regenerate the `terraform-docs` section of the module README and each example README from its
`HEADER.md`. Edit `HEADER.md` for the hand-written header above the markers, then commit the
regenerated `README.md` files alongside your change.

## Pull requests

- Keep changes focused and the history readable.
- Fill in the pull request template, including testing evidence.
- Ensure CI is green: format, validate, lint, scan, and tests all pass before review.

## Reporting issues

Open an issue using the bug report or feature request template. Include versions (terraform,
azurerm, the action, and LibreDevOpsHelpers) and clear reproduction steps.

## Licence

By contributing, you agree that your contributions are licensed under the
[MIT License](./LICENSE).
