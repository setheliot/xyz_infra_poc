# Define enviornment stage name
variable "env_name" {
  description = "unknown"
  type        = string
}

# Define the EKS cluster name
variable "eks_cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

# Define the instance type for EKS nodes
variable "instance_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
  default     = "t3.micro"
}

# AWS Region to deploy the EKS cluster
variable "aws_region" {
  description = "AWS region to deploy the EKS cluster"
  type        = string
  default     = "us-east-1"
}

# VPC name
variable "vpc_name" {
  description = "VPC name"
  type        = string
}

