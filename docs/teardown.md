# Teardown

## Normal destroy (app resources)

```bash
cd terraform
terraform destroy -auto-approve
```

Removes VPC, subnets, IGW, route tables, EC2, security groups, IAM roles/policies,
SSM endpoints, flow logs. This is the "clean state" gate for the project.

## Full teardown (including remote state)

The S3 state bucket and DynamoDB lock table are owned by `bootstrap/` and intentionally
survive `terraform destroy`, because the main config reads its state out of them.
To remove **everything** after the main destroy:

```bash
cd bootstrap
terraform destroy -auto-approve        # deletes bucket + lock table while state is safe
cd ..
```

At this point `terraform/backend.tf` points at a bucket that no longer exists. Re-run
`bootstrap` before the next `apply`.

## Orphan check

Verify nothing was left behind in the AWS console:

- EC2 → Instances: none
- VPC → Your VPCs: none (including the default VPC untouched)
- S3: no state bucket
- IAM → Roles: no `ec2-ssm-role-*` / `ops-ssm-role-*` / `vpc-flow-logs-role-*`
- CloudWatch → Log groups: no `/aws/vpc/flow-logs-*`

## Cost check

Confirm the next-day billing snapshot shows no EC2/endpoint charges. State bucket +
DynamoDB left running cost pennies/month if you skip the bootstrap destroy.
