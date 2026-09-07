# modules/eks

Reusable module that provisions a production-hardened EKS cluster, including:

- EKS control plane (IAM role + `AmazonEKSClusterPolicy` attachment)
- Managed node group with a custom Launch Template that enforces:
  - **IMDSv2** (`http_tokens = required`, hop-limit = 1)
  - **Encrypted EBS root volumes** (gp3, 20 GiB)
- Node IAM role with `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, and `AmazonEC2ContainerRegistryReadOnly`
- OIDC identity provider for the cluster (prerequisite for IRSA)
- EBS CSI driver add-on with a dedicated IRSA role scoped to `kube-system:ebs-csi-controller-sa`

## Usage

```hcl
module "eks" {
  source = "../modules/eks"

  name_prefix         = "nonprod"
  kubernetes_version  = "1.30"
  private_subnet_ids  = module.vpc.private_subnet_ids   # or from remote_state
  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 4
}
```

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `kubernetes_version` | The Kubernetes version for the EKS control plane. | `string` | n/a | yes |
| `name_prefix` | Prefix for naming resources (e.g. prod, nonprod, shared). | `string` | n/a | yes |
| `node_desired_size` | Desired number of worker nodes. | `number` | n/a | yes |
| `node_instance_types` | EC2 instance types for the worker nodes. | `list(string)` | n/a | yes |
| `node_max_size` | Maximum number of worker nodes. | `number` | n/a | yes |
| `node_min_size` | Minimum number of worker nodes. | `number` | n/a | yes |
| `private_subnet_ids` | Private subnet IDs where the control plane ENIs and worker nodes live. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_certificate_authority` | Base64 CA cert used to authenticate to the cluster. |
| `cluster_endpoint` | The API server endpoint (what kubectl talks to). |
| `cluster_name` | The EKS cluster name. |
| `node_group_name` | The managed node group name. |
| `oidc_provider_arn` | ARN of the cluster OIDC provider (for building more IRSA roles later). |

## Resources

| Name | Type |
|------|------|
| [aws_eks_addon.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ebs_csi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
<!-- END_TF_DOCS -->
