output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.website.name
}

output "repository_url" {
  description = "ECR URI, without an image tag"
  value       = aws_ecr_repository.website.repository_url
}
