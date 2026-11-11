variable "aws_region" {
  description = "AWS region in which ECS and networking resources will be created"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Prefix used for separately named AWS resources; changing it creates a different environment"
  type        = string
  default     = "morays-upgrade-docker"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,22}$", var.project_name))
    error_message = "project_name must be 3-23 characters: lower-case letters, digits, and hyphens, starting with a letter."
  }
}

variable "image_uri" {
  description = "Full existing ECR Docker image URI, including a unique tag"
  type        = string
}

variable "desired_count" {
  description = "How many Fargate tasks to keep running (1 for a low-cost demo)"
  type        = number
  default     = 1
  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 4
    error_message = "desired_count must be between 1 and 4."
  }
}