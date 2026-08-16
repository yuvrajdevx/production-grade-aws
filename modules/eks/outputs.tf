output "cluster_name" {
  description = "The EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "The API server endpoint (what kubectl talks to)."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64 CA cert used to authenticate to the cluster."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "ARN of the cluster OIDC provider (for building more IRSA roles later)."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "node_group_name" {
  description = "The managed node group name."
  value       = aws_eks_node_group.this.node_group_name
}
