variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types for the worker nodes."
  type        = list(string)
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
}
