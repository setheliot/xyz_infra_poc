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

  public_subnet_tags = {
    "kubernetes.io/role/elb"                            = "1"  # ✅ Required for ALB
    "kubernetes.io/cluster/${var.eks_cluster_name}"      = "owned"  # Links subnet to EKS
    "Name"                                               = "${var.vpc_name}-public-subnet"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                   = "1"  # For internal load balancers
    "kubernetes.io/cluster/${var.eks_cluster_name}"     = "owned"
    "Name"                                              = "${var.vpc_name}-private-subnet"
  }

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

locals {
  iam_role_name = "eks-node-role-${var.eks_cluster_name}"
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
    xyz_managed_nodes = {
      name = "managed-eks-nodes"
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type      = "AL2023_x86_64_STANDARD"
      instance_type = var.instance_type

      min_size     = 1
      max_size     = 5
      desired_size = 3

      # Setup a custom launch teplate for the managed nodes
      # Notes these settings are the same as the defaults
      use_custom_launch_template = true
      create_launch_template     = true

      # Enable Instance Metadata Service (IMDS)
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }

      # Attach the managed policies for DynamoDB and SSM access by the nodes
      iam_role_name = local.iam_role_name
      iam_role_additional_policies = {
        dynamodb_access = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
        ssm_access      = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      } # iam_role_additional_policies
    }   # xyz_managed_nodes
  }     # eks_managed_node_groups

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = var.env_name
    Terraform   = "true"
  }
}

# Create VPC endpoints (Private Links) for SSM Session Manager access to nodes
resource "aws_security_group" "vpc_endpoint_sg" {
  name   = "vpc-endpoint-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    description     = "Allow EKS Nodes to access VPC Endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_security_group.id]
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

resource "aws_vpc_endpoint" "private_link_ssm" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids         = module.vpc.private_subnets

  tags = {
    Environment = var.env_name
    Terraform   = "true"
  }
}

resource "aws_vpc_endpoint" "private_link_ssmmessages" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids         = module.vpc.private_subnets

  tags = {
    Environment = var.env_name
    Terraform   = "true"
  }
}

resource "aws_vpc_endpoint" "private_link_ec2messages" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids         = module.vpc.private_subnets

  tags = {
    Environment = var.env_name
    Terraform   = "true"
  }
}

# DynamoDb table
resource "aws_vpc_endpoint" "private_link_dynamodb" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Environment = var.env_name
    Terraform   = "true"
  }
}

resource "aws_dynamodb_table" "guestbook" {
  name             = "guestbook"
  billing_mode     = "PROVISIONED"
  read_capacity    = 2
  write_capacity   = 2
  hash_key         = "GuestID"
  range_key        = "Name"
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  attribute {
    name = "GuestID"
    type = "S"
  }

  attribute {
    name = "Name"
    type = "S"
  }

  tags = {
    Environment = var.env_name
    Terraform   = "true"
  }
}