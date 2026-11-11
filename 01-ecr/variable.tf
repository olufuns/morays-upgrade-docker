variable "aws_region" {
  description = "AWS region used for the ECR repository"
  type        = string
  default     = "eu-west-2"
}

variable "repository_name" {
  description = "A unique ECR repository name in this AWS account and region"
  type        = string
  default     = "morays-devops-upgrade-docker"
}