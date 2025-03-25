#### Terraform Backend ###
terraform {
   backend "s3" {
    bucket         = "your-unique-bucket-name" # <- Change this variable to your bucket name
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Providers ###
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}


# # Test code locally
# provider "aws" {
#   region                      = "us-east-1"
#   access_key                  = "null"
#   secret_key                  = "null"
#   s3_force_path_style         = true
#   skip_credentials_validation = true
#   skip_metadata_api_check     = true
#   skip_requesting_account_id  = true

#   endpoints {
#     s3  = "http://localhost:4566"
#     sts = "http://localhost:4566"
#   }
# }

### Modules ##
module "networking" {
  source = "./modules/networking"
  vpc_cidr  = var.vpc_cidr
  public_cidrs = var.public_cidrs
  private_cidrs = var.private_cidrs

}

module "EKS" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  vpc_id             = module.networking.vpc_id
  subnet_ids         = concat(module.networking.public_subnets, module.networking.private_subnets)
  security_group_ids = [module.networking.eks_sg]
  account_id         = var.account_id
  aws_region         = var.aws_region
}