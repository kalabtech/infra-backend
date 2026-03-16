# infra-backend

> Terraform modules to provision a secure AWS remote state backend using S3, DynamoDB, and KMS.

## Features
- S3 bucket with versioning, TLS enforcement, and KMS encryption
- KMS customer-managed key with root policy integrated with S3
- DynamoDB table for state locking (on-demand capacity)
- Modular structure with providers per module

## Stack
- **IaC:** Terraform
- **Cloud:** AWS
  - S3 — stores logs with lifecycle policies
  - KMS — keeps logs encrypted in S3
  - DynamoDB — provides LockID state
- **CI:** GitHub Actions Checks
  - Trivy
  - TFlint
  - Terraform Validate
  - Terraform Format

## Repository Structure
```
infra-cloudtrail-logging/
├── infra/                    # Root Terraform configuration and module coordination
├── modules/
│   ├── dynamoDB/             # DynamoDB table (LockID) without PITR
│   ├── kms/                  # KMS key with root policy access
│   └── s3-bucket/            # S3 bucket lifecycle policy
├── backends/                 # Remote backend config hcl.example
├── environments/             # Variable definitions terraform.tfvars.example
├── docs/                     # Architecture
└── scripts/                  # Terraform plan summary script
```

## Prerequisites
- Terraform `>= 1.14.0`
- AWS Provider `~> 5.0`
- AWS CLI installed and configured with a named profile
- Copy and fill in your values:
  - `environments/terraform.tfvars`

## Usage

### Without makedfile
```bash
terraform -chdir=infra init
terraform -chdir=infra plan -var-file=../environments/terraform.tfvars
terraform -chdir=infra apply -var-file=../environments/terraform.tfvars
```
### With makefile
```bash
make init
make plan
make apply
```

## Design decisions
- **KMS + S3 in single module** — KMS is only used for this bucket, no reuse case. Keeping them together reduces complexity without losing clarity.
- **Static Glue table over Crawler** — CloudTrail schema doesn't change, so a Crawler adds cost for no benefit.
- **Partition projection** — Athena computes S3 paths from date partitions directly, no full bucket scans.
- **Single-region trail** — cost optimization. Multi-region recommended for production.
- **No hardcoded values** — account ID and credentials in GitHub Secrets, region and environment in GitHub Variables.
