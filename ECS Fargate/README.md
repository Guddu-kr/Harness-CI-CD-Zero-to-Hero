# ECS Fargate Infrastructure (Terraform + GitHub Actions)

## What This Creates

```
AWS Infrastructure:
├── VPC (10.1.0.0/16 — custom, NOT default VPC)
│   ├── Public Subnet 1 (us-east-1a)
│   ├── Public Subnet 2 (us-east-1b)
│   ├── Internet Gateway
│   └── Route Table
├── ECS Cluster (Fargate — serverless, no EC2 to manage)
├── Application Load Balancer (internet-facing)
│   ├── Prod Listener (port 80) → Blue Target Group
│   └── Stage Listener (port 8080) → Green Target Group
├── 2 Target Groups (Blue + Green — for Blue-Green deployment)
├── Security Groups (ALB + ECS tasks)
├── IAM Roles (Task Execution + Task)
├── CloudWatch Log Group (/ecs/online-shopping)
└── S3 Bucket (Terraform state — reuses existing)

GitHub Actions:
├── Manual trigger with options:
│   ├── Plan (preview changes)
│   ├── Apply (create infrastructure)
│   └── Destroy (delete EVERYTHING including deployed services, bill = $0)
└── Uses OpenID Connect (no AWS keys stored!)
```

---

## How Blue-Green Works with This Infrastructure

```
BEFORE DEPLOY:
  ALB Listener (port 80) → Blue Target Group → [Task v1, Task v1]

DURING DEPLOY (Harness does this):
  ALB Listener (port 80) → Blue TG → [Task v1]  ← users still here
  ALB Stage Listener (8080) → Green TG → [Task v2]  ← testing new version

AFTER HEALTH CHECK PASSES:
  ALB Listener (port 80) → Green TG → [Task v2]  ← users switched instantly
  Blue TG → [Task v1]  ← kept for rollback

ROLLBACK (if needed):
  ALB Listener (port 80) → Blue TG → [Task v1]  ← instant switch back
```

---

## Prerequisites (Same as EKS — Already Done)

| What | Where |
|------|-------|
| OIDC Provider in AWS | IAM → Identity providers (from EKS setup) |
| IAM Role for GitHub Actions | IAM → Roles (from EKS setup) |
| S3 Bucket for state | S3 (reuses same bucket, different key) |
| GitHub Variables | Settings → Variables (`AWS_ROLE_ARN`, `S3_BUCKET_NAME`) |
| GitHub Environment | Settings → Environments → `production` |

> If you already set up the EKS infrastructure (kubernetes/), these are already done. Same OIDC, same role, same S3 bucket.

---

## How to Run

### Create Infrastructure:

1. GitHub → **Actions** → **"ECS Fargate Terraform"**
2. Click **Run workflow**
3. Select: `apply`
4. Click **Run workflow**
5. Wait ~2 minutes (ECS is much faster than EKS!)
6. Output: ALB URL + Cluster name + Target Group ARNs

### Destroy Infrastructure (bill = $0):

1. GitHub → **Actions** → **"ECS Fargate Terraform"**
2. Click **Run workflow**
3. Select: `destroy`
4. Confirm: type `yes`
5. Run → Deletes ECS services + cluster + ALB + VPC → $0

---

## What Happens on Destroy

```
1. Pre-Destroy Cleanup (handles Harness-deployed services):
   ├── Scale all ECS services to 0 tasks
   ├── Force-delete all ECS services
   ├── Deregister all task definitions
   └── Delete ECR repository

2. Terraform Destroy (infrastructure):
   ├── Delete ALB + Listeners
   ├── Delete Target Groups
   ├── Delete ECS Cluster
   ├── Delete Security Groups
   ├── Delete Subnets + Route Tables
   ├── Delete Internet Gateway
   └── Delete VPC

3. If Destroy Fails (retry):
   ├── Cleanup orphaned ENIs
   ├── Cleanup Security Groups
   └── Retry Terraform Destroy

4. Post-Destroy Verification:
   └── List remaining ECS clusters + ALBs (should be empty)
```

---

## After Apply — Next Steps (Harness Setup)

| # | What | Where |
|---|------|-------|
| 1 | Create Service: `online-shopping` | CD → Services → Type: ECS |
| 2 | Add Task Definition manifest | Service → Manifests |
| 3 | Add Service Definition manifest | Service → Manifests |
| 4 | Add ECR Artifact Source | Service → Artifacts |
| 5 | Create Infrastructure: `ecs-fargate` | Inside Environment → ECS type |
| 6 | Import Pipeline from Git | CD → Pipelines |
| 7 | Run Pipeline | Blue-Green Deploy! |

---

## Cost

```
Running:   ~$0.50/day (Fargate pay-per-use + ALB fixed cost)
             ALB: ~$0.023/hour = $0.55/day
             Fargate: ~$0.04/hour per task (256 CPU, 512 MB)
Destroyed: $0.00
```

> Much cheaper than EKS ($3.73/day) because Fargate only charges for running tasks.

---

## Terraform Outputs (Used in Harness)

| Output | Used For |
|--------|----------|
| `ecs_cluster_name` | Harness Infrastructure → Cluster |
| `alb_dns_name` | Access app: `http://ALB-DNS-NAME` |
| `blue_target_group_arn` | Harness Pipeline → Prod Target Group |
| `green_target_group_arn` | Harness Pipeline → Stage Target Group |
| `prod_listener_arn` | Harness Pipeline → Prod Listener |
| `stage_listener_arn` | Harness Pipeline → Stage Listener |
| `task_execution_role_arn` | ECS Task Definition → executionRoleArn |
| `task_role_arn` | ECS Task Definition → taskRoleArn |
| `ecs_security_group_id` | ECS Service → networkConfiguration |
| `subnet_ids` | ECS Service → networkConfiguration |

---

## Files

```
ECS Fargate/
├── README.md              ← This file
└── terraform/
    ├── main.tf            ← All resources (VPC, ALB, ECS, IAM)
    ├── variables.tf       ← region, app_name, container_port
    └── outputs.tf         ← ARNs needed by Harness pipeline
```
