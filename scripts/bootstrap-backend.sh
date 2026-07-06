#!/usr/bin/env bash
# One-time bootstrap: S3 bucket + DynamoDB table for Terraform remote state.
# Run locally with AWS CLI configured (before first GitHub Actions deploy).
#
# Usage:
#   export AWS_REGION=us-east-1
#   export TF_STATE_BUCKET=your-unique-bucket-name
#   export TF_STATE_DYNAMODB_TABLE=failover-lab-tf-locks
#   ./scripts/bootstrap-backend.sh

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:?Set TF_STATE_BUCKET to a globally unique S3 bucket name}"
TF_STATE_DYNAMODB_TABLE="${TF_STATE_DYNAMODB_TABLE:-failover-lab-tf-locks}"
PROJECT_NAME="${PROJECT_NAME:-failover-lab}"

echo "Creating S3 bucket: ${TF_STATE_BUCKET} (${AWS_REGION})"
if [ "${AWS_REGION}" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "${TF_STATE_BUCKET}" --region "${AWS_REGION}"
else
  aws s3api create-bucket \
    --bucket "${TF_STATE_BUCKET}" \
    --region "${AWS_REGION}" \
    --create-bucket-configuration "LocationConstraint=${AWS_REGION}"
fi

aws s3api put-bucket-versioning \
  --bucket "${TF_STATE_BUCKET}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "${TF_STATE_BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

aws s3api put-public-access-block \
  --bucket "${TF_STATE_BUCKET}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Creating DynamoDB lock table: ${TF_STATE_DYNAMODB_TABLE}"
aws dynamodb create-table \
  --table-name "${TF_STATE_DYNAMODB_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${AWS_REGION}" \
  2>/dev/null || echo "DynamoDB table may already exist — continuing."

cat <<EOF

Bootstrap complete.

1. Copy config/backend.hcl.example to backend.hcl and set:
     bucket         = "${TF_STATE_BUCKET}"
     dynamodb_table = "${TF_STATE_DYNAMODB_TABLE}"
     region         = "${AWS_REGION}"

2. Add these GitHub repository Variables (Settings → Actions → Variables):
     TF_STATE_BUCKET         = ${TF_STATE_BUCKET}
     TF_STATE_KEY            = failover-lab/terraform.tfstate
     TF_STATE_REGION         = ${AWS_REGION}
     TF_STATE_DYNAMODB_TABLE = ${TF_STATE_DYNAMODB_TABLE}

3. Run: terraform init -backend-config=backend.hcl

EOF
