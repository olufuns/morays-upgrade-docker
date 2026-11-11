output "website_url" {
  description = "Open this address to view the Morays site (HTTP for this demo)"
  value       = "http://${aws_lb.website.dns_name}"
}

output "alb_dns_name" {
  value = aws_lb.website.dns_name
}

output "cluster_name" {
  value = aws_ecs_cluster.website.name
}

output "service_name" {
  value = aws_ecs_service.website.name
}

output "target_group_arn" {
  value = aws_lb_target_group.website.arn
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.ecs.name
}
