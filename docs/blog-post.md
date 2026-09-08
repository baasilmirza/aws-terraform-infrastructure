# Terraform for people who hate click-ops

*How I stopped hand-crafting AWS resources in the console and started treating infrastructure like code — and what it actually cost me.*

> Companion repo: [baasilmirza/aws-terraform-infrastructure](https://github.com/baasilmirza/aws-terraform-infrastructure)

Every AWS console click is a decision you made once, understood for a minute, and will never review again. A `terraform apply` is a decision you made once, in a diff, in a pull request, with a reviewer's eyeballs on it — and it's repeatable forever.

That's the whole pitch. This post walks through why I moved to Infrastructure as Code, the tradeoffs of remote state, how I drew module boundaries, and the least-privilege IAM rules that make the setup survivable.

---

## Why IaC (and why not just scripts)

The naive alternative is "scripts that call `aws ec2 create-vpc`". Scripts work until the fifth time someone runs them and a resource already exists. Terraform gives you four things scripts don't:

1. **Declarative intent** — you describe the end state, not the steps.
2. **A graph** — it figures out ordering (IAM profile before EC2, subnets before instances).
3. **A diff** — `terraform plan` shows exactly what will change before anything does.
4. **State** — it remembers what it created, so `destroy` actually cleans up.

That last one is the quiet superpower. "How do I delete the thing I made three months ago?" is the most common cloud question nobody can answer. With Terraform the answer is one command.

## Remote state: the tradeoffs nobody puts in the marketing

Terraform stores its memory in a state file. Locally, that file sits on your laptop — which means your "infrastructure source of truth" disappears when the laptop does, and two people applying at once will stomp each other.

So I moved state to S3 with a DynamoDB lock table:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "project02/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

What you trade:

- **For:** shared state (a team can apply from anywhere), **versioning** (every state change is recoverable — I have accidentally deleted things; versioning has un-deleted them), **locking** (no two applies racing).
- **Against:** you now have a new "source of truth" to secure, and there's a bootstrapping question — the bucket that holds state has to exist before Terraform can use it.

I solve the bootstrapping with a separate `bootstrap/` config that creates the bucket + lock table, and — this is the part that confused me initially — the state bucket is **not** owned by the main config. If `terraform destroy` owned the bucket it reads state from, destroy would try to delete the very file it's writing to. Classic chicken-and-egg. Separate lifecycle, problem gone.

## Module boundaries: where I drew the lines

Modules are the difference between "one 400-line main.tf" and something a new engineer can read in an afternoon. My rule of thumb: a module owns one *concern*, and cross-module references only flow through explicit inputs and outputs.

```text
terraform/
├── bootstrap/          # S3 state bucket + DynamoDB lock (created once)
├── modules/
│   ├── network/        # VPC, subnets, IGW, route tables, flow logs
│   ├── compute/        # security group + EC2 instance
│   └── iam/            # instance role + operator role
├── main.tf             # wires modules + SSM VPC endpoints
└── backend.tf          # S3 remote state
```

**`network/`** — VPC, one public subnet (internet gateway, no NAT), one private subnet, route tables, flow logs. No NAT gateway: that's ~$32/month of nothing, and a private instance doesn't need it if you use VPC endpoints instead.

**`compute/`** — the interesting part. The EC2 instance lives in the *private* subnet with **no public IP and no SSH key**. You manage it exclusively through AWS Session Manager over VPC endpoints. The security group has zero inbound rules. Zero. Not "22 from my IP", zero. There's nothing to SSH into because there's no SSH server to reach.

**`iam/`** — see below.

The dependency that forced me to keep SSM endpoints at the root instead of burying them in a module: endpoints need both the VPC (from `network`) *and* the instance security group (from `compute`). That's a "connects two modules" concern, so it lives where both outputs are visible — a nice forcing function for honest boundaries.

## IAM least privilege: the policy is the security review

The boring truth about IAM: you will never remove permissions you granted "just in case". Least privilege means the default answer is *no*, and you add only what the workload demonstrably needs.

**Instance role** — the EC2 box may do exactly one thing: talk to the SSM agent plane. AWS ships a purpose-built managed policy for that: `AmazonSSMManagedInstanceCore`. One attachment, scoped to exactly the SSM agent actions, done. No `AdministratorAccess`, no broad `ec2:*`.

**Operator role** — sessions are the classic privilege-escalation vector, so I scoped them with a resource tag:

```json
{
  "Sid": "AllowSsmSessionsOnStack",
  "Effect": "Allow",
  "Action": ["ssm:StartSession", "ssm:TerminateSession", "ssm:ResumeSession"],
  "Resource": [
    "arn:aws:ssm:REGION:ACCOUNT:document/SSM-SessionManagerRunShell",
    "arn:aws:ssm:REGION:ACCOUNT:instance/*"
  ],
  "Condition": {
    "StringEquals": { "aws:ResourceTag/Environment": "dev" }
  }
}
```

The operator can start a session on *this* stack's instance — and nothing else in the account. If they want a session on another environment's box, they need that team's role.

The demo that makes this concrete: my config has a boolean that, flipped to `false`, attaches an explicit `Deny` to the same role. Re-apply, try to start a session, and you get `AccessDeniedException` — even though the `Allow` is still there, because in IAM a `Deny` always wins. Flip it back, sessions work again. Least privilege isn't a one-time exercise; being able to *break and prove* the boundary is what makes it real.

## `terraform plan` before / after

`plan` is where IaC earns its keep. Before: "I'll just create an SG and remember to delete it." After:

```text
Terraform will perform the following actions:

  # module.compute.aws_instance.app will be created
  + resource "aws_instance" "app" {
      + ami                     = "ami-0..."
      + instance_type           = "t3.micro"
      + monitoring              = true
      + vpc_security_group_ids  = (known after apply)
      ...
    }

Plan: 29 to add, 0 to change, 0 to destroy.
```

Every resource, every change, reviewed *before* it happens — and reviewable as a diff in a pull request by someone who isn't you.

## What it cost

Real number: I ran the full stack — VPC, EC2 t3.micro, three SSM VPC endpoints, flow logs — applied, verified, destroyed in the same session. Total AWS bill for the exercise: **well under $0.10**. The EC2 instance alone is ~$0.011/hour. Destroy is the last command you run, so the meter stops.

The design choices that keep the bill near zero:

- No NAT gateway (saves ~$32/month vs. the "default" tutorial setup)
- No ALB, no RDS, no managed databases
- t3.micro, destroyed the same day

## The takeaway

Infrastructure as Code isn't about the tool — it's about making infrastructure *reviewable* and *recoverable*. The S3 state bucket means my infrastructure has version control. The module boundaries mean a stranger can read it. The IAM policies mean a compromise of one role doesn't own the account.

And the demo works best when you deliberately break it: add a Deny, watch sessions die, explain the diff, fix it. That five-minute arc teaches more about IAM than any dashboard ever will.

---

*Scanned with Checkov (90 checks, 0 failures) before and after apply. Full code, docs, and a teardown guide live in the repo.*
