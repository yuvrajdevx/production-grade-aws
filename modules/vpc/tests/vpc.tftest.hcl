mock_provider "aws" {}

variables {
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  availability_zones   = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  name_prefix          = "test"
}

run "vpc_uses_expected_cidr" {
  command = plan

  assert {
    condition     = aws_vpc.aws-vpc.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block did not match the expected 10.0.0.0/16"
  }
}

run "creates_three_public_subnets" {
  command = plan

  assert {
    condition     = length(aws_subnet.public_subnets) == 3
    error_message = "Expected exactly 3 public subnets, one per AZ"
  }
}

run "creates_three_private_subnets" {
  command = plan

  assert {
    condition     = length(aws_subnet.private_subnets) == 3
    error_message = "Expected exactly 3 private subnets, one per AZ"
  }
}
