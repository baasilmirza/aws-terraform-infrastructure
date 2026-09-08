data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# ---- Instance role: only what the SSM agent needs -----------------------
resource "aws_iam_role" "ec2_ssm" {
  name = "ec2-ssm-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  description = "Least-privilege instance role: SSM agent connectivity only"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_managed" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "ec2-ssm-profile-${var.environment}"
  role = aws_iam_role.ec2_ssm.name
}

# ---- Ops role: scoped SSM session + read-only access (least privilege) --
resource "aws_iam_role" "ops" {
  name = "ops-ssm-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
      }
    ]
  })

  description = "Operator role with SSM session + read-only access scoped by tag"
}

resource "aws_iam_policy" "ops_ssm_scoped" {
  name        = "ops-ssm-scoped-${var.environment}"
  description = "Minimal SSM session + EC2 read-only, scoped to this stack"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSsmSessionsOnStack"
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:ResumeSession"
        ]
        Resource = [
          "arn:aws:ssm:${var.region}:${local.account_id}:document/SSM-SessionManagerRunShell",
          "arn:aws:ssm:${var.region}:${local.account_id}:instance/*"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Environment" = var.environment
          }
        }
      },
      {
        Sid    = "AllowDescribeScopedToStack"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = [
          "arn:aws:ec2:${var.region}:${local.account_id}:instance/*"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Environment" = var.environment
          }
        }
      },
      {
        # ssm:DescribeInstanceInformation / GetConnectionStatus are not
        # resource-based actions, so "*" is the only valid resource.
        Sid    = "AllowSsmStatusQuery"
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation",
          "ssm:GetConnectionStatus"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ops_ssm_scoped" {
  role       = aws_iam_role.ops.name
  policy_arn = aws_iam_policy.ops_ssm_scoped.arn
}

# Explicit Deny used to demonstrate least privilege: flip the var, re-apply,
# and the ops role loses SSM access.
resource "aws_iam_policy" "ops_ssm_deny" {
  count       = var.ssm_session_allowed ? 0 : 1
  name        = "ops-ssm-deny-${var.environment}"
  description = "Explicit Deny on SSM sessions (least-privilege demo)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenySsmSessions"
        Effect = "Deny"
        Action = [
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:ResumeSession"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ops_ssm_deny" {
  count      = var.ssm_session_allowed ? 0 : 1
  role       = aws_iam_role.ops.name
  policy_arn = aws_iam_policy.ops_ssm_deny[0].arn
}
