# Read the VPC layer's outputs straight from its remote state in S3.
# This is the cross-root handoff: prod/ has its OWN state, but needs values
# that live in network/'s state. terraform_remote_state bridges them.
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "yuvraj-tfstate-2026"
    key    = "network/terraform.tfstate"
    region = "ap-south-1"
  }
}

module "eks" {
  source = "../modules/eks"

  name_prefix        = "prod"
  kubernetes_version = var.kubernetes_version

  # The value comes from network/'s output — launched into the private subnets.
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
}
