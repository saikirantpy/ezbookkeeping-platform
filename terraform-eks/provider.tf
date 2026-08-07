provider "aws" {

  region = var.aws_region

  default_tags {

    tags = {

      Project     = local.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Saikiran"

    }

  }

}