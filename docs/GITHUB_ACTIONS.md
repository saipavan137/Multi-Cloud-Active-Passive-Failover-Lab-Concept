# GitHub Actions deployment guide

Run the entire multi-cloud failover lab from GitHub Actions — no local `terraform apply` required.

## Overview

| Trigger | Action |
|---------|--------|
| **Actions → Run workflow** | `plan`, `apply`, or `destroy` |
| **Pull request to `main`** | Automatic `terraform plan` (commented on PR) |

State is stored in **S3** with **DynamoDB** locking (shared between CI and optional local runs).

## One-time setup

### 1. Create the GitHub repository

```powershell
cd f:\Compsiprep\Project\Terraform
git init
git add .
git commit -m "Add multi-cloud failover lab with GitHub Actions"
```

On GitHub: **New repository** → name it e.g. `multi-cloud-failover-lab` → do not add README (you already have one).

```powershell
git remote add origin https://github.com/YOUR_USERNAME/multi-cloud-failover-lab.git
git branch -M main
git push -u origin main
```

### 2. Bootstrap Terraform remote state (AWS)

Run once locally (AWS CLI configured):

```powershell
$env:AWS_REGION = "us-east-1"
$env:TF_STATE_BUCKET = "your-unique-tf-state-bucket-name"   # globally unique
.\scripts\bootstrap-backend.ps1
```

### 3. Create an Azure service principal

```powershell
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"

az ad sp create-for-rbac `
  --name "failover-lab-github" `
  --role contributor `
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID `
  --sdk-auth
```

Copy the **entire JSON output** — this becomes `AZURE_CREDENTIALS`.

### 4. Add GitHub Secrets

**Settings → Secrets and variables → Actions → Secrets**

| Secret | Value |
|--------|--------|
| `AWS_ACCESS_KEY_ID` | IAM user access key (needs EC2, ELB, Route53, ACM, S3, DynamoDB) |
| `AWS_SECRET_ACCESS_KEY` | IAM secret key |
| `AZURE_CREDENTIALS` | Full JSON from `az ad sp create-for-rbac --sdk-auth` |

### 5. Add GitHub Variables

**Settings → Secrets and variables → Actions → Variables**

| Variable | Example | Required |
|----------|---------|----------|
| `TF_STATE_BUCKET` | `your-unique-tf-state-bucket-name` | Yes |
| `TF_STATE_KEY` | `failover-lab/terraform.tfstate` | Yes |
| `TF_STATE_REGION` | `us-east-1` | Yes |
| `TF_STATE_DYNAMODB_TABLE` | `failover-lab-tf-locks` | Yes |
| `TF_VAR_DOMAIN_NAME` | `saipavan.org` | Yes (if Route 53 enabled) |
| `TF_VAR_ENABLE_AZURE` | `true` | No (default `true`) |
| `TF_VAR_ENABLE_ROUTE53` | `true` | No (default `true`) |
| `TF_VAR_CREATE_HOSTED_ZONE` | `true` | No (default `true`) |
| `TF_VAR_HOSTED_ZONE_ID` | `Z0123...` | Only if `CREATE_HOSTED_ZONE=false` |
| `TF_VAR_AZURE_LOCATION` | `westus2` | No (default `westus2`) |
| `TF_VAR_AZURE_VM_SIZE` | `Standard_D2s_v3` | No |

See `config/lab.tfvars.example` for all tunables.

### 6. IAM permissions (AWS)

The IAM user/role used in GitHub needs at minimum:

- EC2, ELB, VPC full access for the lab
- Route 53 full access (if DNS enabled)
- S3 + DynamoDB access to the state bucket/table

Managed policies for a lab: `AmazonEC2FullAccess`, `ElasticLoadBalancingFullAccess`, `AmazonRoute53FullAccess`, plus S3/DynamoDB on the state resources.

## Run from GitHub Actions

1. Open **Actions** → **Terraform** → **Run workflow**
2. Choose **apply**
3. Wait ~4–5 minutes
4. View **Terraform outputs** in the job log
5. If `create_hosted_zone = true`, update your domain registrar nameservers from the `nameservers` output

### Destroy

1. **Actions** → **Terraform** → **Run workflow**
2. Choose **destroy**
3. Set **confirm_destroy** to exactly: `destroy`

## DNS reminder

Each time you destroy and re-apply with `create_hosted_zone = true`, Route 53 creates a **new** hosted zone with **new nameservers**. Update IONOS (or your registrar) after every fresh deploy.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `Error acquiring state lock` | Another workflow is running; wait or clear stale lock in DynamoDB |
| `NoSuchBucket` on init | Run bootstrap script; verify `TF_STATE_BUCKET` variable |
| Azure `AuthorizationFailed` | Service principal needs **Contributor** on the subscription |
| `domain_name` empty | Set `TF_VAR_DOMAIN_NAME` repository variable |
| PR plan fails | Ensure all secrets/variables are configured on the repo |
