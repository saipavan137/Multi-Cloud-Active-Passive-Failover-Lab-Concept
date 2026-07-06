# Chaos Test Guide — Simulate an AWS Outage

This guide walks you through intentionally breaking the **active AWS environment** and watching Route 53 automatically fail over to **Azure**.

## Before you start

1. Confirm the lab is healthy:

   ```powershell
   terraform output app_url          # Should show AWS (orange badge)
   terraform output aws_alb_url      # Direct AWS — should work
   terraform output azure_lb_url     # Direct Azure — should work
   ```

2. Note your failover timing:

   ```powershell
   terraform output failover_timing
   # Default: ~60 seconds (30s interval × 2 failures)
   ```

3. Open your browser to the `app_url` and keep it ready to refresh.

## Method 1 — Block security group traffic (recommended)

This simulates the app becoming unreachable behind the load balancer — the most realistic scenario for this lab.

### Break AWS

```powershell
$projectName = "failover-lab"   # match project_name in terraform.tfvars
$appSgId = terraform output -raw chaos_test_aws_security_group_id

# Find the ALB security group
$albSgId = aws ec2 describe-security-groups `
  --filters "Name=group-name,Values=${projectName}-alb-sg" `
  --query "SecurityGroups[0].GroupId" --output text

# Remove the rule allowing ALB -> EC2 on port 80
aws ec2 revoke-security-group-ingress `
  --group-id $appSgId `
  --protocol tcp `
  --port 80 `
  --source-group $albSgId
```

**What happens:**
- ALB can no longer reach EC2 on port 80
- ALB target becomes unhealthy
- Route 53 health check to `/health` starts failing

### Observe failover

```powershell
# Watch health check status (repeat every 15s)
$hcId = terraform output -raw route53_health_check_id
aws route53 get-health-check-status --health-check-id $hcId
```

Timeline:

| Time | Event |
|------|-------|
| T+0s | You block the security group |
| T+30s | First health check failure |
| T+60s | Second failure → AWS marked unhealthy |
| T+60-90s | DNS resolves to Azure; refresh browser |

Refresh `app_url` — you should see the **blue Azure badge**.

### Restore AWS

```powershell
$appSgId = terraform output -raw chaos_test_aws_security_group_id
$albSgId = aws ec2 describe-security-groups `
  --filters "Name=group-name,Values=failover-lab-alb-sg" `
  --query "SecurityGroups[0].GroupId" --output text

aws ec2 authorize-security-group-ingress `
  --group-id $appSgId `
  --protocol tcp `
  --port 80 `
  --source-group $albSgId
```

After ~60 seconds of healthy checks, Route 53 routes traffic back to AWS.

---

## Method 2 — Stop nginx on the EC2 instance

Simulates the application process crashing while the instance stays up.

### Break AWS

```powershell
$instanceId = terraform output -raw chaos_test_aws_instance_id

# If SSM is available:
aws ssm send-command `
  --instance-ids $instanceId `
  --document-name "AWS-RunShellScript" `
  --parameters commands="sudo systemctl stop nginx"
```

If SSM is not configured on the instance, use Method 1 instead.

### Restore AWS

```powershell
aws ssm send-command `
  --instance-ids $instanceId `
  --document-name "AWS-RunShellScript" `
  --parameters commands="sudo systemctl start nginx"
```

---

## Method 3 — Stop the EC2 instance (dramatic)

```powershell
$instanceId = terraform output -raw chaos_test_aws_instance_id
aws ec2 stop-instances --instance-ids $instanceId
```

Restore:

```powershell
aws ec2 start-instances --instance-ids $instanceId
# Wait for instance + nginx to come back (~2 min)
```

---

## Verify with DNS lookup

```powershell
$fqdn = (terraform output -raw app_url) -replace "http://",""
nslookup $fqdn
```

- **Healthy:** resolves to AWS ALB IPs
- **Failed over:** resolves to Azure Load Balancer public IP

---

## Learning checklist

- [ ] I can explain the path: User → Route 53 → Load Balancer → VM
- [ ] I triggered an outage and saw failover within ~60 seconds
- [ ] I verified the Azure page appears after failover
- [ ] I restored AWS and saw traffic return to the primary
- [ ] I understand why both clouds use identical `/health` endpoints
