# modules/vpc

Reusable module that provisions a complete, single-AZ-or-multi-AZ VPC with:

- One VPC with DNS support enabled
- `N` public subnets (one per AZ, `map_public_ip_on_launch = true`)
- `N` private subnets (one per AZ)
- Internet Gateway attached to the VPC
- Single NAT Gateway in `public_subnets[0]` with an associated Elastic IP
- Public route table (default route → IGW) associated with all public subnets
- Private route table (default route → NAT GW) associated with all private subnets

> **Cost note.** The NAT Gateway and Elastic IP incur charges while running.
> Use `terraform plan` to evaluate changes without incurring cost.

## Usage

```hcl
module "vpc" {
  source = "../modules/vpc"

  name_prefix          = "nonprod"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}
```

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `availability_zones` | A list of availability zones for the subnets. | `list(string)` | n/a | yes |
| `name_prefix` | A prefix for naming resources. | `string` | n/a | yes |
| `private_subnet_cidrs` | A list of CIDR blocks for the private subnets. | `list(string)` | n/a | yes |
| `public_subnet_cidrs` | A list of CIDR blocks for the public subnets. | `list(string)` | n/a | yes |
| `vpc_cidr` | The CIDR block for the VPC. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| `private_subnet_ids` | IDs of the private subnets. |
| `public_subnet_ids` | IDs of the public subnets. |
| `vpc_id` | ID of the created VPC. |

## Resources

| Name | Type |
|------|------|
| [aws_eip.eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_internet_gateway.igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.nat_gw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.private_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.aws-vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
<!-- END_TF_DOCS -->
