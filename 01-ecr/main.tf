provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "morays-upgrade-docker"
      ManagedBy = "Terraform"
    }
  }
}

resource "aws_ecr_repository" "website" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Retain the most recent 15 versioned images. Helps control image storage costs.
resource "aws_ecr_lifecycle_policy" "keep_recent" {
  repository = aws_ecr_repository.website.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the latest 15 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 15
        }
        action = { type = "expire" }
      }
    ]
  })
}
