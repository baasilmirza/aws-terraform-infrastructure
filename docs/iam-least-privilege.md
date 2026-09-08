# IAM least privilege: policy walkthrough and break/fix demo

## Instance role (`ec2-ssm-role`)

The EC2 instance may do exactly one thing: talk to the SSM agent plane. That is the
single managed policy `AmazonSSMManagedInstanceCore`. Nothing else — no S3, no
describe-everything, no admin.

## Ops role (`ops-ssm-role`)

Assumable by any principal in the account (trust: account root), carrying two ideas:

1. **Resource scoping by tag** — `ssm:StartSession/TerminateSession/ResumeSession` are
   allowed only on instances whose `Environment` tag matches the stack, and only against
   the `SSM-SessionManagerRunShell` document. Start a session on *any other* instance →
   denied.
2. **Read-only, but split** — `ec2:Describe*` is scoped to the same tagged instance;
   `ssm:DescribeInstanceInformation`/`GetConnectionStatus` are not resource-based
   actions, so `"Resource": "*"` is the only legal value for them.

## Break-and-fix demo (this is the YouTube bit)

1. Assume the ops role:

   ```bash
   aws sts assume-role --role-arn <ops_role_arn output> --role-session-name demo
   # export the returned AccessKeyId/SecretAccessKey/SessionToken
   ```

2. Start a session against the instance — **allowed**:

   ```bash
   aws ssm start-session --target <instance_id>
   ```

3. Break the policy — set `ssm_session_allowed = false` and re-apply:

   ```bash
   terraform apply -var ssm_session_allowed=false -auto-approve
   ```

   This attaches an explicit `Deny` on SSM session actions to the ops role.

4. Assume the role again (fresh credentials) and try to start a session — **denied**
   with `AccessDeniedException`. Note the Deny wins over the Allow in the same policy.

5. Fix it — flip the variable back to `true` and re-apply. Sessions work again.

```hcl
# The toggle that drives the demo
variable "ssm_session_allowed" {
  description = "True = allow SSM sessions on this stack via the ops role; false = add an explicit Deny"
  type        = bool
  default     = true
}
```

The takeaway: least privilege is not static. This shows what happens when you
introduce a Deny, how a reviewer sees the diff, and how IAM evaluation resolves
Allow/Deny.
