output "app_url" {
  description = "Application URL via Route 53 (when enable_route53 = true)."
  value       = var.enable_route53 ? "${var.enable_https ? "https" : "http"}://${local.app_fqdn}" : null
}

output "aws_alb_url" {
  description = "Direct AWS ALB URL — use this in AWS-only mode."
  value       = module.aws_active.alb_url
}

output "azure_lb_url" {
  description = "Direct Azure Load Balancer URL (only when enable_azure = true)."
  value       = var.enable_azure ? module.azure_passive[0].load_balancer_url : null
}

output "route53_health_check_id" {
  description = "Route 53 health check monitoring the AWS ALB."
  value       = var.enable_route53 ? aws_route53_health_check.aws_primary[0].id : null
}

output "failover_timing" {
  description = "Approximate time before Route 53 marks AWS unhealthy."
  value       = var.enable_azure && var.enable_route53 ? "~${var.health_check_interval * var.health_check_failure_threshold} seconds (${var.health_check_interval}s interval × ${var.health_check_failure_threshold} failures)" : null
}

output "chaos_test_aws_instance_id" {
  description = "EC2 instance to stop or modify during chaos testing."
  value       = module.aws_active.instance_id
}

output "chaos_test_aws_security_group_id" {
  description = "Security group to block HTTP during chaos testing."
  value       = module.aws_active.app_security_group_id
}

output "azure_vm_name" {
  description = "Azure VM name."
  value       = var.enable_azure ? module.azure_passive[0].vm_name : null
}

output "azure_resource_group" {
  description = "Azure resource group."
  value       = var.enable_azure ? module.azure_passive[0].resource_group_name : null
}

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID."
  value       = local.zone_id
}

output "nameservers" {
  description = "Route 53 nameservers (update your domain registrar if you created a new zone)."
  value       = var.enable_route53 && var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : null
}

output "deployment_mode" {
  description = "Active deployment configuration."
  value       = var.enable_azure ? "multi-cloud (AWS + Azure)" : "aws-only"
}
