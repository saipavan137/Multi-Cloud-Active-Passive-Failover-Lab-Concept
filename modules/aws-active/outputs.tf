output "alb_dns_name" {
  description = "DNS name of the AWS Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Route 53 hosted zone ID for the ALB (used for alias records)."
  value       = aws_lb.main.zone_id
}

output "instance_id" {
  description = "EC2 instance ID (useful for chaos testing via CLI)."
  value       = aws_instance.app.id
}

output "app_security_group_id" {
  description = "Security group attached to the EC2 instance."
  value       = aws_security_group.app.id
}

output "alb_url" {
  description = "Direct URL to the AWS ALB (bypasses Route 53)."
  value       = "http://${aws_lb.main.dns_name}"
}
