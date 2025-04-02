# Roles EKS
resource "aws_iam_role" "cluster_iam_role" {
  name = "EKSWorkerNodeRole"

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

resource "aws_iam_role_policy_attachment" "eks_worker_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.cluster_iam_role.name
}

resource "aws_iam_role_policy_attachment" "eks_worker_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.cluster_iam_role.name
}

resource "aws_iam_role_policy_attachment" "eks_worker_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.cluster_iam_role.name
}

# IAM Roles
resource "aws_iam_role" "codepipeline_role" {
  name = "grpc-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "codepipeline.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_codestarconnections_connection" "repo_git" {
  name          = "example-connection"
  provider_type = "GitHub"
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "codecommit:*",
          "codebuild:*",
          "s3:*",
          "eks:*",
          "ecr:*"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["codestar-connections:UseConnection"],
        Resource = [aws_codestarconnections_connection.repo_git.arn]
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ],
        Resource = "*"
      }
    ]
  })
}



resource "aws_iam_role" "codebuild_role" {
  name = "grpc-codebuild_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "grpc-codebuild_role"
  }
}

# Role codebuild
resource "aws_iam_policy" "codebuild_policy" {
  name = "codebuild-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "codecommit:GitPull",
          "eks:*",
          "sts:GetCallerIdentity"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_s3_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = "1.32"
  cluster_endpoint_public_access = true
  cluster_additional_security_group_ids = var.security_group_ids

  enable_cluster_creator_admin_permissions = true
  authentication_mode  = "API_AND_CONFIG_MAP"

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 2
      desired_size = 1
      instance_types = ["t3.small"]
      vpc_security_group_ids = var.security_group_ids
    }
  }

access_entries = {
  codebuild_role = {
    principal_arn     = "${aws_iam_role.codebuild_role.arn}"
    kubernetes_groups = []
    policy_associations = {
      admin_access = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }
    }
  }
}

  iam_role_arn  = aws_iam_role.cluster_iam_role.arn
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

module "lb_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${var.cluster_name}_eks_lb"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["app-grpc:aws-load-balancer-controller"]
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

resource "helm_release" "lb" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "app-grpc"
  depends_on = [
    kubernetes_service_account.service-account
  ]

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
}

resource "kubernetes_service_account" "service-account" {
  metadata {
    name = "aws-load-balancer-controller"
    namespace = "app-grpc"
    labels = {
        "app.kubernetes.io/name"= "aws-load-balancer-controller"
        "app.kubernetes.io/component"= "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = module.lb_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}

# ECR Repositories
resource "aws_ecr_repository" "server" {
  name = "grpc-server"
}

resource "aws_ecr_repository" "client" {
  name = "grpc-client"
}

# CodePipeline Artifact Bucket
resource "aws_s3_bucket" "artifacts" {
  bucket = "grpc-pipeline-artifacts-${var.account_id}"
}

# CodeBuild Project
resource "aws_codebuild_project" "build" {
  depends_on = [aws_ecr_repository.server]
  name          = "grpc-ecr-build"
  service_role  = aws_iam_role.codebuild_role.arn
  
  artifacts {
    type = "NO_ARTIFACTS"
  }
  
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
    
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.account_id
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "ECR_SERVER_REPOSITORY"
      value = aws_ecr_repository.server.repository_url
    }
    environment_variable {
      name  = "ECR_CLIENT_REPOSITORY"
      value = aws_ecr_repository.client.repository_url
    }
  }
  
  source {
    type            = "GITHUB"
    location        = "https://github.com/aalexcruzz/simetrik-test"
    git_clone_depth = 1
    buildspec       = "code_grpc/buildspec.yml" 
    git_submodules_config {
      fetch_submodules = false
    }
  }

}


# CodeBuild Project for Deploy
resource "aws_codebuild_project" "deploy" {
  name          = "grpc-eks-deploy"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "CLUSTER_NAME"
      value = module.eks.cluster_name
    }
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "ECR_SERVER_REPOSITORY"
      value = aws_ecr_repository.server.repository_url
    }
    environment_variable {
      name  = "ECR_CLIENT_REPOSITORY"
      value = aws_ecr_repository.client.repository_url
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOT
      version: 0.2
      phases:
        install:
          commands:
            - curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            - sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            - chmod +x ./kubectl
            - mkdir -p ~/.local/bin
            - mv ./kubectl ~/.local/bin/kubectl
            - aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
            - sudo apt-get update && sudo apt-get install -y gettext 
        build:
          commands:
            - envsubst < code_grpc/kubernetes/server-deployment.yaml | kubectl apply -f -
            - envsubst < code_grpc/kubernetes/client-deployment.yaml | kubectl apply -f -
            - envsubst < code_grpc/kubernetes/ingress.yaml | kubectl apply -f -
    EOT
  }
}


resource "aws_codepipeline" "pipeline" {
  name     = "grpc-full-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.repo_git.arn
        FullRepositoryId = "aalexcruzz/simetrik-test"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "EKS-Deploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"
      configuration = {
        ProjectName = aws_codebuild_project.deploy.name
      }
    }
  }
}