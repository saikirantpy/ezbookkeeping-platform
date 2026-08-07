###############################################
# Local Values
###############################################

locals {

  #############################################
  # Naming Convention
  #############################################

  project_name = "${var.project_name}-${var.environment}"

  #############################################
  # Common Tags
  #############################################

  common_tags = {

    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"

  }

}