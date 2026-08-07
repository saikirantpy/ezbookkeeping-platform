###############################################
# Amazon ECR Repository
###############################################

resource "aws_ecr_repository" "main" {

  name = var.project_name

  image_tag_mutability = "MUTABLE"

  force_delete = true

  image_scanning_configuration {

    scan_on_push = true

  }

  tags = merge(

    local.common_tags,

    {

      Name = "${local.project_name}-ecr"

    }

  )

}