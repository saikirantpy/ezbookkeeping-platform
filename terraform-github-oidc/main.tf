
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"

  default_tags {
    tags = {
      Project     = "ezbookkeeping"
      Environment = "dev"
      ManagedBy   = "Terraform"
      Owner       = "Saikiran"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  project_name  = "ezbookkeeping-dev"
  github_repo   = "saikirantpy/ezbookkeeping-platform"
  github_branch = "feature/github-actions"
}

# GitHub Actions identity provider
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "${local.project_name}-github-actions-oidc"
  }
}

# Trust only the selected GitHub repository and branch
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.github_actions.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:saikirantpy@48900440/ezbookkeeping-platform@1322654300:ref:refs/heads/feature/github-actions"
      ]
    }
  }
}

# Persistent GitHub Actions IAM role
resource "aws_iam_role" "github_actions" {
  name               = "${local.project_name}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name = "${local.project_name}-github-actions-role"
  }
}

output "github_actions_role_arn" {
  description = "IAM role assumed by GitHub Actions through OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}


resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "${local.project_name}-github-actions-ecr"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "ECRAuthorization"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "PushEzBookkeepingImage"
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage"
        ]

        Resource = "arn:aws:ecr:ap-south-1:356627769772:repository/ezbookkeeping"
      }
    ]
  })
}
resource "aws_ecr_repository" "application" {
  name                 = "ezbookkeeping"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${local.project_name}-ecr"
  }
}

output "ecr_repository_url" {
  description = "ECR repository URL for the application"
  value       = aws_ecr_repository.application.repository_url
}