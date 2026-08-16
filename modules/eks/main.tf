###############################################################################
# 1. CONTROL PLANE IAM ROLE
#    Identity the EKS *service* assumes to manage AWS resources on your behalf.
###############################################################################

# The role itself. The assume_role_policy (a.k.a. "trust policy") answers ONE
# question: "WHO is allowed to wear this role?" Here: the EKS service.
resource "aws_iam_role" "cluster" {
  name = "${var.name_prefix}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

# Attaches an AWS-managed permission policy to the role above.
# The trust policy said WHO can wear the role; this says WHAT the role can DO.
resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

###############################################################################
# 2. EKS CLUSTER (the control plane)
###############################################################################
resource "aws_eks_cluster" "this" {
  name     = "${var.name_prefix}-cluster"
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids = var.private_subnet_ids
  }

  # Make sure the role's permissions exist BEFORE the cluster tries to use them,
  # and stay until AFTER the cluster is deleted.
  depends_on = [aws_iam_role_policy_attachment.cluster]
}

###############################################################################
# 3. WORKER NODE IAM ROLE
#    Identity the EC2 worker instances assume. Note the DIFFERENT principal:
#    ec2.amazonaws.com (the nodes ARE EC2), not eks.amazonaws.com.
###############################################################################
resource "aws_iam_role" "node" {
  name = "${var.name_prefix}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# The three managed policies every worker node needs. for_each stamps out one
# attachment per ARN in the set.
resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",          # join & operate in the cluster
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",               # pod networking (VPC CNI)
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", # pull images from ECR
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

###############################################################################
# 4. LAUNCH TEMPLATE — security hardening for the nodes
#    Enforces IMDSv2 and encrypts the node root volume.
###############################################################################
resource "aws_launch_template" "node" {
  name_prefix = "${var.name_prefix}-node-"

  # IMDSv2 enforcement:
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # <-- forces IMDSv2 (token required)
    http_put_response_hop_limit = 1          # blocks pods from reaching node metadata
  }

  # EBS encryption on the node's root disk:
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
    }
  }
}

###############################################################################
# 5. MANAGED NODE GROUP — the actual EC2 worker machines
###############################################################################
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name_prefix}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids # workers live in PRIVATE subnets
  instance_types  = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  # Nodes can't function until their role has the 3 policies attached.
  depends_on = [aws_iam_role_policy_attachment.node]
}

###############################################################################
# 6. OIDC PROVIDER — the foundation of IRSA
#    Registers the cluster's identity system with IAM so pods can assume roles.
###############################################################################
resource "aws_iam_openid_connect_provider" "this" {
  url            = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
  # thumbprint_list omitted: AWS provider v5 fetches the CA thumbprint for us.
}

locals {
  # The issuer URL without the https:// prefix — used to build IAM condition keys.
  oidc_host = replace(aws_iam_openid_connect_provider.this.url, "https://", "")
}

###############################################################################
# 7. IRSA ROLE for the EBS CSI driver
#    A role a POD can assume — scoped to ONE specific Kubernetes service account.
###############################################################################
resource "aws_iam_role" "ebs_csi" {
  name = "${var.name_prefix}-ebs-csi-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      # Note: a DIFFERENT action than before — web identity federation, not plain AssumeRole.
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.this.arn }
      Condition = {
        StringEquals = {
          # Only THIS service account, in kube-system, may assume the role:
          "${local.oidc_host}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

###############################################################################
# 8. EBS CSI DRIVER ADDON
###############################################################################
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  depends_on = [aws_eks_node_group.this] # needs nodes for its pods to run on
}
