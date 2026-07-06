# One-time bootstrap for Terraform remote state (PowerShell).
# Requires AWS CLI configured.
#
# Usage:
#   $env:AWS_REGION = "us-east-1"
#   $env:TF_STATE_BUCKET = "your-unique-bucket-name"
#   .\scripts\bootstrap-backend.ps1

$ErrorActionPreference = "Stop"

$AwsRegion = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }
$Bucket = $env:TF_STATE_BUCKET
if (-not $Bucket) { throw "Set TF_STATE_BUCKET to a globally unique S3 bucket name" }
$LockTable = if ($env:TF_STATE_DYNAMODB_TABLE) { $env:TF_STATE_DYNAMODB_TABLE } else { "failover-lab-tf-locks" }

Write-Host "Creating S3 bucket: $Bucket ($AwsRegion)"
if ($AwsRegion -eq "us-east-1") {
    aws s3api create-bucket --bucket $Bucket --region $AwsRegion | Out-Null
} else {
    aws s3api create-bucket --bucket $Bucket --region $AwsRegion `
        --create-bucket-configuration "LocationConstraint=$AwsRegion" | Out-Null
}

aws s3api put-bucket-versioning --bucket $Bucket `
    --versioning-configuration Status=Enabled | Out-Null

$encryption = '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-bucket-encryption --bucket $Bucket `
    --server-side-encryption-configuration $encryption | Out-Null

aws s3api put-public-access-block --bucket $Bucket `
    --public-access-block-configuration `
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" | Out-Null

Write-Host "Creating DynamoDB lock table: $LockTable"
try {
    aws dynamodb create-table `
        --table-name $LockTable `
        --attribute-definitions AttributeName=LockID,AttributeType=S `
        --key-schema AttributeName=LockID,KeyType=HASH `
        --billing-mode PAY_PER_REQUEST `
        --region $AwsRegion | Out-Null
} catch {
    Write-Host "DynamoDB table may already exist — continuing."
}

Write-Host @"

Bootstrap complete.

1. Copy config\backend.hcl.example to backend.hcl and set bucket/dynamodb_table/region.
2. Add GitHub repository Variables:
     TF_STATE_BUCKET         = $Bucket
     TF_STATE_KEY            = failover-lab/terraform.tfstate
     TF_STATE_REGION         = $AwsRegion
     TF_STATE_DYNAMODB_TABLE = $LockTable
3. Run: terraform init -backend-config=backend.hcl

"@
