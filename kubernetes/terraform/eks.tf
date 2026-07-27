# ═══════════════════════════════════════════════════════════════════
# Amazon EKS Cluster — AUTO MODE (No node groups to manage!)
# AWS handles: compute scaling, VPC CNI, load balancers, EBS CSI
# ═══════════════════════════════════════════════════════════════════

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })
}

# Cluster role policies (ALL required for Auto Mode)
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSComputePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSBlockStoragePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSLoadBalancingPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSNetworkingPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-eks-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  # Allow bastion to reach EKS API server
  ingress {
    description     = "Allow bastion to access EKS API"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-eks-sg"
  }
}

# KMS Key for EKS secrets encryption
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.cluster_name}-eks-kms"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# ═══════════════════════════════════════════════════════════════════
# EKS Cluster with AUTO MODE ENABLED
# No managed node groups needed. AWS provisions nodes automatically.
# ═══════════════════════════════════════════════════════════════════
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  # Required when EKS Auto Mode is enabled
  bootstrap_self_managed_addons = false

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id,
      aws_subnet.public_1.id,
      aws_subnet.public_2.id,
    ]
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # ┌─────────────────────────────────────────────────┐
  # │         EKS AUTO MODE CONFIGURATION              │
  # │  Enables: Compute, Networking, Storage           │
  # │  No node groups, no Karpenter, no CSI drivers    │
  # │  AWS manages everything automatically            │
  # └─────────────────────────────────────────────────┘

  # Auto Mode: Compute (replaces managed node groups + Karpenter)
  compute_config {
    enabled       = true
    node_pools    = ["general-purpose", "system"]
    node_role_arn = aws_iam_role.eks_nodes.arn
  }

  # Auto Mode: Networking (replaces VPC CNI addon + AWS LB Controller)
  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  # Auto Mode: Storage (replaces EBS CSI driver addon)
  storage_config {
    block_storage {
      enabled = true
    }
  }

  # Envelope encryption for Kubernetes secrets
  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  # Enable audit logging
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
    aws_iam_role_policy_attachment.cluster_AmazonEKSComputePolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSBlockStoragePolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSLoadBalancingPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSNetworkingPolicy,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodeMinimalPolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryPullOnly,
  ]

  tags = {
    Name = var.cluster_name
  }
}

# ═══════════════════════════════════════════════════════════════════
# IAM Role for Auto Mode Nodes (EC2 instances managed by AWS)
# ═══════════════════════════════════════════════════════════════════
resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodeMinimalPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryPullOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  role       = aws_iam_role.eks_nodes.name
}

# ═══════════════════════════════════════════════════════════════════
# EKS Access Entry — Allow GitHub Actions OIDC role to deploy
# NOTE: Update github_actions_role_name variable with your actual role name
# Find it in: GitHub repo → Settings → Secrets → Variables → AWS_ROLE_ARN
# ═══════════════════════════════════════════════════════════════════
# data "aws_caller_identity" "current" {}
#
# resource "aws_eks_access_entry" "github_actions" {
#   cluster_name  = aws_eks_cluster.main.name
#   principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.github_actions_role_name}"
#   type          = "STANDARD"
# }
#
# resource "aws_eks_access_policy_association" "github_actions" {
#   cluster_name  = aws_eks_cluster.main.name
#   principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.github_actions_role_name}"
#   policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
#
#   access_scope {
#     type = "cluster"
#   }
# }
