variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "harness-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "bastion_instance_type" {
  description = "Bastion EC2 instance type"
  type        = string
  default     = "t2.medium"
}

variable "bastion_key_name" {
  description = "Not used - connecting via SSM Session Manager (no key pair needed)"
  type        = string
  default     = ""
}

variable "github_actions_role_name" {
  description = "IAM role name used by GitHub Actions OIDC (for EKS access)"
  type        = string
  default     = "github-actions-role"
}
