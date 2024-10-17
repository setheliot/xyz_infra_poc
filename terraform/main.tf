#
# VPC and Subnets
data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.13.0"

  name            = var.vpc_name
  cidr            = "10.0.0.0/16"
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    Terraform   = "true"
    Environment = var.env_name
  }
}

#
# Security Group for EKS Cluster
resource "aws_security_group" "eks_security_group" {
  name   = "eks_security_group_${var.env_name}"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust based on security needs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.env_name
    Terraform   = "true"
  }
}

#
# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = "1.31"

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  # coredns, kube-proxy, and vpc-cni are automatically installed by EKS         
  cluster_addons = {
    eks-pod-identity-agent = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    managed_nodes = {
      name = "managed-eks-nodes"
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type      = "AL2023_x86_64_STANDARD"
      instance_type = var.instance_type

      min_size     = 1
      max_size     = 5
      desired_size = 3
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = var.env_name
    Terraform   = "true"
  }
}


