# 🚀 Episode 7, Topic 2 — Deploy Online Shopping to ECS (Blue-Green)

## Flow

```
Create ECS Infra (GitHub Actions) → Create Service in Harness → Import Pipeline → Run → ALB URL
```

---

## Prerequisites (Already Done)

| What | Episode | Link |
|------|---------|------|
| GitHub connector (`account.Github`) | 1 | [Episode 1](../Episode-01/hello-world-app/DEPLOY-STEPS.md) |
| AWS OIDC connector (`account.aws_account`) | 3 | [Episode 3](../Episode-03/README.md#connector-3-aws--🆕-create-now) |
| Secret: `aws_access_key_id` | 3 | [Episode 3](../Episode-03/terraform-project/README.md#step-2-get-aws-access-key--secret-key) |
| Secret: `aws_secret_access_key` | 3 | [Episode 3](../Episode-03/terraform-project/README.md#step-3-add-secrets-in-harness) |
| Variable: `aws_account_id` | 4 | [Episode 4](../Episode-04/README.md#step-1-add-variable-aws_account_id-in-harness) |
| Variable: `aws_region` | 3 | [Episode 3](../Episode-03/terraform-project/README.md#step-4-add-variables-in-harness) |

---

## Step 1: Create ECS Infrastructure

1. GitHub → Actions → **"ECS Fargate Terraform"** → Run workflow → `action: apply`
2. Wait ~2 minutes
3. Output: ECS Cluster + ALB URL

---

## Step 2: Create Service in Harness UI

1. CD → **Services** → **+ New Service**
2. Name: `online-shopping` (ID auto-generates as `onlineshopping`)
3. Setup: **Inline**
4. Deployment Type: **Amazon ECS**
5. **Manifests** → **+ Add Manifest**:
   - **Task Definition:**
     - Type: ECS Task Definition
     - Store: GitHub → Connector: `account.Github`
     - Repo: `Harness-CI-CD-Zero-to-Hero`
     - Branch: `master`
     - File Path: `Episode-07/Online Shopping app/ecs/task-definition.json`
     - Submit
   - **Service Definition:**
     - Type: ECS Service Definition
     - Store: GitHub → Connector: `account.Github`
     - Repo: `Harness-CI-CD-Zero-to-Hero`
     - Branch: `master`
     - File Path: `Episode-07/Online Shopping app/ecs/service-definition.json`
     - Submit
6. **Artifacts** → **+ Add Artifact Source**:
   - Artifact Repository Type: **ECR**
   - Connector: `account.aws_account`
   - Artifact Source Identifier: `ecr_image`
   - Region: `us-east-1` (your region)
   - Registry ID: leave empty
   - Image Path: `online-shopping`
   - Tag: **Value** → `<+input>`
   - Submit
7. Save

---

## Step 3: Create Environment + Infrastructure in Harness UI

1. Reuse Environment: `development` (already created in Episode 6/7)
2. Inside `development` → **+ Infrastructure Definition**
3. Name: `ecs-fargate` (ID auto-generates as `ecsfargate`)
4. Deployment Type: **Amazon ECS**
5. Setup: **Inline**
6. Connector: `account.aws_account` (AWS OIDC connector)
7. Region: `us-east-1`
8. Cluster: `online-shopping-cluster`
9. Save

---

## Step 4: Push Code to GitHub

```bash
git add .
git commit -m "Episode 7: Online Shopping ECS Blue-Green"
git push origin master
```

---

## Step 5: Import Pipeline

1. CD → Pipelines → **+ Create a Pipeline** → **Import from Git**
2. Connector: `Github`
3. Repo: `Harness-CI-CD-Zero-to-Hero`
4. Branch: `master`
5. YAML Path: `Episode-07/Online Shopping app/.harness/pipeline-ecs-cd.yaml`
6. Import

---

## Step 6: Run Pipeline

```
Stage 1: Build & Push to ECR ✅
Stage 2: Deploy to ECS Blue-Green ✅
  ├── EcsBlueGreenCreateService (deploys new task def to Green target group)
  ├── Health Check (Green target group healthy?)
  ├── EcsBlueGreenSwapTargetGroups (swap: users now hit Green)
  └── Rollback (auto on failure):
      └── EcsBlueGreenRollback (swap back to Blue — instant!)
```

---

## Step 7: Access App

From GitHub Actions apply output or AWS Console:
```
http://online-shopping-alb-XXXXXXXXX.us-east-1.elb.amazonaws.com
```

---

## Blue-Green Flow

```
BEFORE:   ALB (port 80) → Blue TG → [v1 tasks]
DEPLOY:   ALB (port 8080) → Green TG → [v2 tasks]  (testing)
SWAP:     ALB (port 80) → Green TG → [v2 tasks]  (live!)
ROLLBACK: ALB (port 80) → Blue TG → [v1 tasks]  (instant!)
```

---

## Cleanup

```
GitHub → Actions → "ECS Fargate Terraform" → destroy → confirm: yes
```

Deletes: ECS services + cluster + ALB + VPC → $0

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Cluster not found" | Run ECS Fargate Terraform apply first |
| "Service not found" | Create `online-shopping` in Harness Services UI |
| "No eligible delegates" | ECS doesn't need delegate — check AWS connector |
| Health check failing | Check container starts on port 8080, responds at `/` |
| Image pull error | Verify ECR repo `online-shopping` exists + image pushed |
