locals {
  app_fqdn = var.enable_route53 ? "${var.app_subdomain}.${var.domain_name}" : ""
}

# ---------------------------------------------------------------------------
# Active environment — AWS (EC2 + ALB)
# ---------------------------------------------------------------------------

module "aws_active" {
  source = "./modules/aws-active"

  project_name    = var.project_name
  aws_region      = var.aws_region
  instance_type   = var.aws_instance_type
  enable_https    = var.enable_route53 && var.enable_https
  certificate_arn = var.enable_route53 && var.enable_https ? aws_acm_certificate_validation.app[0].certificate_arn : ""
}

# ---------------------------------------------------------------------------
# HTTPS — free ACM certificate (phones/browsers default to https://)
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "app" {
  count = var.enable_route53 && var.enable_https ? 1 : 0

  domain_name       = local.app_fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-cert"
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_route53 && var.enable_https ? {
    for dvo in aws_acm_certificate.app[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

resource "aws_acm_certificate_validation" "app" {
  count = var.enable_route53 && var.enable_https ? 1 : 0

  certificate_arn         = aws_acm_certificate.app[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ---------------------------------------------------------------------------
# Passive environment — Azure (VM + Load Balancer)
# ---------------------------------------------------------------------------

module "azure_passive" {
  count  = var.enable_azure ? 1 : 0
  source = "./modules/azure-passive"

  project_name   = var.project_name
  location       = var.azure_location
  vm_size        = var.azure_vm_size
  admin_username = var.azure_admin_username
}

# ---------------------------------------------------------------------------
# Route 53 — optional; requires a hosted zone and route53 IAM permissions
# ---------------------------------------------------------------------------

resource "aws_route53_zone" "main" {
  count = var.enable_route53 && var.create_hosted_zone ? 1 : 0
  name  = var.domain_name
}

data "aws_route53_zone" "existing" {
  count   = var.enable_route53 && !var.create_hosted_zone ? 1 : 0
  zone_id = var.hosted_zone_id
}

locals {
  zone_id = var.enable_route53 ? (
    var.create_hosted_zone ? aws_route53_zone.main[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  ) : null
}

resource "aws_route53_health_check" "aws_primary" {
  count = var.enable_route53 ? 1 : 0

  fqdn              = module.aws_active.alb_dns_name
  port              = var.enable_https ? 443 : 80
  type              = var.enable_https ? "HTTPS" : "HTTP"
  resource_path     = "/health"
  request_interval  = var.health_check_interval
  failure_threshold = var.health_check_failure_threshold
  enable_sni        = var.enable_https ? true : null

  tags = {
    Name = "${var.project_name}-aws-health-check"
  }
}

# Simple alias record (AWS-only mode)
resource "aws_route53_record" "app" {
  count = var.enable_route53 && !var.enable_azure ? 1 : 0

  zone_id = local.zone_id
  name    = local.app_fqdn
  type    = "A"

  alias {
    name                   = module.aws_active.alb_dns_name
    zone_id                = module.aws_active.alb_zone_id
    evaluate_target_health = true
  }
}

# Failover PRIMARY record (multi-cloud mode)
resource "aws_route53_record" "primary" {
  count = var.enable_route53 && var.enable_azure ? 1 : 0

  zone_id = local.zone_id
  name    = local.app_fqdn
  type    = "A"

  set_identifier = "aws-primary"
  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = module.aws_active.alb_dns_name
    zone_id                = module.aws_active.alb_zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.aws_primary[0].id
}

# Failover SECONDARY record (multi-cloud mode)
resource "aws_route53_record" "secondary" {
  count = var.enable_route53 && var.enable_azure ? 1 : 0

  zone_id = local.zone_id
  name    = local.app_fqdn
  type    = "A"

  set_identifier = "azure-secondary"
  failover_routing_policy {
    type = "SECONDARY"
  }

  ttl     = 60
  records = [module.azure_passive[0].load_balancer_public_ip]
}
