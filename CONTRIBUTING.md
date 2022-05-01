# Contributing to Libre DevOps repos
We love your input and welcome community inclusion wherever possible. 

We want to make contributing to the community and projects as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## We Develop with Github
We use Github to host code, to track issues and feature requests, as well as accept pull requests.

## If you aren't a maintainer yet
Pull requests are the best way to propose changes to the codebase (we use [Github Flow](https://guides.github.com/introduction/flow/index.html)). We actively welcome your pull requests

## Code style and workflow
The example workflow for Terraform submissions is as follows, but is applicable for other pieces of code generally:
1. Fork the repo and create your branch from `main`.
2. Ensure you have tested your code with `terraform validate`, `tfsec` and `checkov` or other linting and security tools.
3. Format your terraform using `terraform fmt -recursive` or another code formtter, such as [prettier](https://prettier.io/)
4. Module files and variable should use a "What you see is what you get" naming convention (WYSIWYG), so for example:
```shell
terraform-${provider}-${purpose}/ # Provider may be azurerm for example, and provider might be virtual-network for example
|
├── ${purpose}.tf # For the main terraform function of the terraform code, e.g. a virtual network, so should be called vnet.tf
├── input.tf      # For input variables
├── LICENSE       # MIT License only
├── locals.tf     # For locals if needed
├── output.tf     # For output variables
├── README.md     # README documentation
```
5. All `README.md` files should be contain content.  For Terraform, it should always have an example code block of a successful execution of the module, followed by a [terraform-docs](https://github.com/terraform-docs/terraform-docs) output, using the markdown format, for example:

```shell
terraform-docs markdown . >> README.md
```

6. All variables should be placed in alphabetical order.  For terraform, this can be done using the the util script:
```shell
curl https://raw.githubusercontent.com/libre-devops/utils/dev/scripts/terraform/tf-sort.sh | bash
```
7. Issue that pull request!

## Any contributions you make will be under the MIT Software License
In short, when you submit code changes, your submissions are understood to be under the same [MIT License](http://choosealicense.com/licenses/mit/) that covers the project. Feel free to contact the maintainers if that's a concern.

## Report bugs using Github's [issues](https://github.com/briandk/transcriptase-atom/issues)
We use GitHub issues to track public bugs. Report a bug by [opening a new issue](); it's that easy!

## Write bug reports with detail, background, and sample code

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can. 
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

People *love* thorough bug reports. I'm not even kidding.


## License
By contributing, you agree that your contributions will be licensed under its MIT License.