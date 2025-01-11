# Output the VPC ID
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# Output the EKS cluster details
output "eks_cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS Cluster API Endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_arn" {
  description = "EKS Cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_node_iam_role_name" {
  description = "EKS Nodes IAM Role Name"
  value       = module.eks.eks_managed_node_groups["xyz_managed_nodes"].iam_role_name
}


# Output the AWS Region
output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

