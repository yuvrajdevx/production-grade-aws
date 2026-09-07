# tflint configuration used by both CI and the pre-commit hook.
plugin "aws" {
  enabled = true
  version = "0.36.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
