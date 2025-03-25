# Terraform Setup for Simetrik Test

This repository contains Terraform configurations to deploy infrastructure on AWS. Follow the steps below to set up and deploy the environment.

## Prerequisites

- **Terraform** installed (v1.0+ recommended)
- **AWS CLI** configured with appropriate credentials
- An AWS account with permissions to create S3 buckets, VPCs, EKS clusters, etc.
- An existing S3 bucket for Terraform state storage

---

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/aalexcruzz/simetrik-test
cd simetrik-test
```

### 2. Configure the S3 Backend
Update the Terraform state backend configuration in `main.tf`:
```hcl
# main.tf (line 4)
bucket = "your-unique-bucket-name"  # Replace with your S3 bucket name
```
Ensure the S3 bucket **already exists** in your AWS account.

### 3. Set Up Variables
Create a `terraform.tfvars` file in the root directory and populate it with your AWS details:
```hcl
# terraform.tfvars
aws_profile   = "your_aws_profile"    # e.g., "default"
aws_region    = "your_aws_region"     # e.g., "us-east-1"
account_id    = "your_aws_account_id" 
vpc_cidr      = "10.0.0.0/16"
public_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
cluster_name  = "your-cluster-name"   # e.g., "simetrik-eks-cluster"
```

### 4. Initialize and Deploy
```bash
terraform init    # Downloads providers and initializes the backend
terraform plan    # Preview changes
terraform apply   # Deploy infrastructure (type "yes" to confirm)
```

---

## Variables Description
| Variable        | Description                                                                 |
|-----------------|-----------------------------------------------------------------------------|
| `aws_profile`   | AWS CLI profile name for authentication.                                    |
| `aws_region`    | AWS region where resources will be deployed (e.g., `us-east-1`).            |
| `account_id`    | Your AWS account ID.                                                        |
| `vpc_cidr`      | CIDR block for the VPC (e.g., `10.0.0.0/16`).                               |
| `public_cidrs`  | List of CIDR blocks for public subnets.                                     |
| `private_cidrs` | List of CIDR blocks for private subnets.                                    |
| `cluster_name`  | Name for the EKS cluster (if applicable).                                   |

---

## Important Notes
- **S3 Bucket**: The bucket specified in `main.tf` must exist before running `terraform init`.
- **AWS Permissions**: Ensure your IAM user/role has permissions to create the specified resources.
- **Cost Alert**: Running this setup may incur AWS costs (VPC, EKS, EC2, etc.).

---

## Clean Up
To destroy all resources created by Terraform:
```bash
terraform destroy
```

---

**Replace all placeholders** (e.g., `your-unique-bucket-name`, `your_aws_profile`) with your actual values before using.