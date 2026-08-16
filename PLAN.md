# Production-Grade AWS EKS Platform — Design Plan

Decisions made during the architecture discussion. This is the blueprint; code comes next.

## What we're building

A production-style AWS platform in Terraform:

- One shared VPC, public + private subnets across 3 AZs (6 subnets total)
- 3 EKS clusters: prod, non-prod, shared-services
- EBS CSI driver for persistent storage (via IRSA)
- Remote state in S3 + DynamoDB locking
- Security defaults: IMDSv2 enforced, EBS encryption by default
- Reusable, self-written modules (VPC + EKS)
- Later: GitHub Actions CI (fmt/validate/plan on PRs) + one terraform test / Terratest

## Key decisions and the reasoning

### 1. Single shared VPC (not one per environment)
Three VPCs win on blast radius, security boundaries, and per-team ownership — that's
the true production answer. For THIS project we chose a single shared VPC because:
- Lower cost: all 3 clusters share ONE set of NAT gateways instead of three.
  (Note: a VPC is free, VPC peering is basically free; NAT gateways + Transit Gateway
  are the real cost drivers.)
- Lower complexity: no peering / Transit Gateway to build, so we can focus on EKS + modules.

### 2. Modules vs. roots
- A **module** = reusable code (like a function). No state of its own. Never applied directly.
- A **root** = a directory you run `terraform apply` in. Has its own state. Calls modules.
- We write ONE `modules/eks` and call it 3× with different inputs — not three copies.

### 3. Cross-state references
`network/` owns the VPC and exposes subnet IDs as **outputs**. Each cluster root reads
them via the **`terraform_remote_state`** data source (tight but explicit coupling).
Alternative considered: `aws_subnets` data source with tag filters (loose coupling,
relies on disciplined tagging). We chose `terraform_remote_state` to demonstrate state
composition.

### 4. State backend + chicken-and-egg
State lives in S3 + DynamoDB. But the S3 bucket must exist before Terraform can use it
as a backend. We break the loop with a **`bootstrap/` root using local state** that
creates the bucket + lock table in code. Everything else then uses that remote backend.
(Alternative: create the bucket manually — simpler, but one thing lives outside IaC.)

## Repository structure

```
modules/
  vpc/          # reusable networking code (no state)
  eks/          # reusable cluster code (no state)
bootstrap/      # ROOT (local state): creates S3 bucket + DynamoDB lock table
network/        # ROOT: calls modules/vpc, owns shared VPC state
prod/           # ROOT: calls modules/eks, reads network via terraform_remote_state
nonprod/        # ROOT: calls modules/eks
shared-svcs/    # ROOT: calls modules/eks
```

## Build order (apply sequence)

```
1. bootstrap/   — first: creates the S3 bucket + DynamoDB table every later
                  config uses as its remote backend.
2. network/     — next: clusters launch INTO its VPC/subnets; needs the
                  bootstrap backend to store its state.
3. prod/ , nonprod/ , shared-svcs/ — last: each reads network's subnet IDs
                  via terraform_remote_state and launches EKS into them.
```

Notes:
- Step 3 is a **fan-out**, not a line: the three cluster roots depend only on
  `network/`, not on each other — they can run in any order or in parallel.
- Sub-ordering INSIDE each cluster (control plane -> OIDC provider -> node group +
  EBS CSI driver via IRSA) is resolved automatically by Terraform's dependency
  graph, as long as resources reference each other by attribute.

## Cost / safety flags (for later, when we code)
- EKS control plane: ~$0.10/hr per cluster — real money, x3.
- NAT gateways: ~$32/mo each + data.
- Strategy: build + `plan` for the portfolio; only `apply` deliberately, destroy after.
