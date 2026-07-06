variable "project_name" {
  description = "Prefix used for resource names and tags."
  type        = string
  default     = "failover-lab"
}

# ---------------------------------------------------------------------------
# Deployment mode
# ---------------------------------------------------------------------------

variable "enable_azure" {
  description = "Deploy the passive Azure standby. Set false for AWS-only mode."
  type        = bool
  default     = false
}

variable "enable_route53" {
  description = "Configure Route 53 DNS records. Set false to use the ALB URL directly (no domain needed)."
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Enable HTTPS on the ALB with a free ACM certificate (requires enable_route53 = true)."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# DNS (Route 53) — only used when enable_route53 = true
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "Root domain you control in Route 53 (e.g. example.com). Required when enable_route53 = true."
  type        = string
  default     = ""
}

variable "app_subdomain" {
  description = "Subdomain for the Hello World app (e.g. app -> app.example.com)."
  type        = string
  default     = "app"
}

variable "create_hosted_zone" {
  description = "Create a new Route 53 hosted zone. Set false if the zone already exists."
  type        = bool
  default     = false
}

variable "hosted_zone_id" {
  description = "Existing Route 53 hosted zone ID (required when create_hosted_zone = false)."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# AWS (Active)
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for the active environment."
  type        = string
  default     = "us-east-1"
}

variable "aws_instance_type" {
  description = "EC2 instance type for the active app server."
  type        = string
  default     = "t3.micro"
}

# ---------------------------------------------------------------------------
# Azure (Passive)
# ---------------------------------------------------------------------------

variable "azure_location" {
  description = "Azure region for the passive standby environment."
  type        = string
  default     = "eastus"
}

variable "azure_vm_size" {
  description = "Azure VM size for the passive app server."
  type        = string
  default     = "Standard_B1s"
}

variable "azure_admin_username" {
  description = "Admin username for the Azure VM."
  type        = string
  default     = "azureuser"
}

# ---------------------------------------------------------------------------
# Health check tuning (~60 s to mark AWS unhealthy)
# Route 53 checks every 30 s; 2 consecutive failures ≈ 60 s.
# ---------------------------------------------------------------------------

variable "health_check_interval" {
  description = "Route 53 health check interval in seconds (10 or 30)."
  type        = number
  default     = 30

  validation {
    condition     = contains([10, 30], var.health_check_interval)
    error_message = "health_check_interval must be 10 or 30."
  }
}

variable "health_check_failure_threshold" {
  description = "Consecutive failures before Route 53 marks the primary unhealthy."
  type        = number
  default     = 2

  validation {
    condition     = var.health_check_failure_threshold >= 1 && var.health_check_failure_threshold <= 3
    error_message = "health_check_failure_threshold must be between 1 and 3."
  }
}
