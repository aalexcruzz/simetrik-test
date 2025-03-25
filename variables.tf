variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "default"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

## Variables EKS
variable "cluster_name" {
  description = "Eks Cluster Name"
  type        = string
}

## Variables Networking
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}
