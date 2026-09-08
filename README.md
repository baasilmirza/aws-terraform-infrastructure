# AWS Infrastructure with Terraform

Version-controlled, reviewable, repeatable AWS infrastructure built with Terraform — no click-ops. Provisions a VPC (public + private subnets, no NAT), one private `t3.micro` EC2 instance reachable only over Session Manager, least-privilege IAM, and remote state in S3 with DynamoDB locking.

## Architecture

```
                        ┌──────────────────────────────┐
                        │        S3 remote state       │
                        │  (versioned + KMS encrypted) │
                        └──────────────▲───────────────┘
                                       │  state + locks
        Terraform ──────────────────── │ ── DynamoDB lock table
                                       │
   ┌───────────────────────────────────▼──────────────────────┐
   │  VPC 10.0.0.0/16                                          │
   │                                                           │
   │  public subnet 10.0.0.0/24      private subnet 10.0.10.0/24 │
   │        └── IGW (no NAT)                └── EC2 t3.micro   │
   │                                        └── SSM VPC endpoints │
   │                                                        │
   └───────────────────────────────────────────────────────────┘
```

Key design choice: the instance sits in a **private** subnet with **no public IP and no NAT**. It is managed exclusively through AWS Session Manager via VPC interface endpoints — no SSH keys, no open inbound ports. The security group has *zero* ingress rules.

## Repository layout

```
terraform/
├── bootstrap/            # one-time state backend: S3 bucket + DynamoDB lock table
├── modules/
│   ├── network/          # VPC, IGW, public+private subnets, route tables, flow logs
│   ├── compute/          # EC2 SG (no inbound) + t3.micro AL2023 instance
│   └── iam/              # SSM instance role + least-privilege ops role
├── main.tf               # wires modules + SSM VPC endpoints
├── backend.tf            # S3 remote state backend
├── variables.tf
├── outputs.tf
└── versions.tf
docs/
├── iam-least-privilege.md   # policy walkthrough + break/fix demo
└── teardown.md              # destroy + orphan cleanup
```

## Why this shape

- **Private instance over SSH-key public instances** — the secure pattern; SSM gives auditable, temporary, credential-free sessions.
- **No NAT gateway** — a private subnet can still reach the SSM control plane through VPC endpoints, avoiding ~$32/month NAT spend.
- **Remote state in S3 with versioning + encryption** — state is a shared, recoverable, auditable artifact; DynamoDB prevents concurrent `apply`s.
- **Separate `bootstrap/`** — the state bucket is its own concern, created once and intentionally not owned by the main config, so `terraform destroy` can't delete the state it is reading.

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with credentials that can create VPC/EC2/IAM/S3/DynamoDB resources
- Python 3.9+ + `checkov` for IaC scanning (`pip install checkov`)

## Quickstart

```bash
cd terraform

# 1. Create the state backend (S3 bucket + DynamoDB lock table)
cd bootstrap
terraform init
terraform apply -auto-approve
cd ..

# 2. Apply the infrastructure (backend.tf points at the bucket from step 1)
terraform init
terraform plan
terraform apply -auto-approve

# 3. Connect to the instance — no SSH keys, no public IP
aws ssm start-session --target <instance_id>   # or use the ssm_connect output
```

> If `terraform init` fails because the state bucket name is already taken, change
> `bucket_name` in `bootstrap/variables.tf` and the `bucket` in `backend.tf` together.

## Validation

```bash
terraform fmt -check -recursive   # formatting
terraform validate                # config validity (root + bootstrap)
checkov -d .                      # IaC security scan
```

Current scan: **90 checks passed, 0 failed**. Suppressions live in `terraform/.checkov.yaml` with per-check reasons (state-bucket logging/replication, CMK vs AWS-managed keys, etc.).

## Security posture

- IAM instance role carries only `AmazonSSMManagedInstanceCore`.
- Operator role's SSM `StartSession` is scoped by `aws:ResourceTag/Environment` — it can only reach this stack's instance.
- IMDSv2 required; EBS and state encrypted; S3 + DynamoDB public access blocked.
- Flow logs shipped to CloudWatch (7-day retention) — see `docs/iam-least-privilege.md` for the break-and-fix demo.

## Destroy

```bash
cd terraform
terraform destroy -auto-approve
```

State bucket and lock table persist intentionally (they are the control plane).
To remove everything, including state, follow `docs/teardown.md`.

## Cost

- EC2 t3.micro ~ $0.011/h (destroyed same session → cents)
- No NAT, no ALB, no RDS. SSM VPC endpoints ~ $0.03/h total while running
- S3 state + DynamoDB: pennies
- 24 h full run ~ $0.35; destroy right after apply → well under $0.10
