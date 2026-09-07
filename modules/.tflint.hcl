# tflint config for reusable modules.
# Modules do not declare providers or required_providers — that is the root
# caller's responsibility. The AWS ruleset plugin is therefore disabled here;
# it is only enabled for the environment roots (network/, prod/, etc.) via the
# root .tflint.hcl. Core tflint rules (terraform_deprecated_*, etc.) still run.
