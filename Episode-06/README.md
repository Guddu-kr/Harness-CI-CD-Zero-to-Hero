# Episode 6: Continuous Delivery to Kubernetes
---

## 📚 Topics Covered

### 1. What is Continuous Delivery (CD)?

```
CI (Episodes 1-5):     Code → Test → Build → Docker Image → Push to ECR

CD (This episode):     Docker Image → Deploy to Server → Users access it

```

### 2. Kubernetes Concepts

| Concept | What It Is | Analogy |
|---------|-----------|---------|
| Namespace | Logical isolation | Floor in a building |
| ConfigMap | Non-secret config | Instructions on the fridge |
| Secret | Passwords, keys | Safe in the bedroom |
| Deployment | Manages pods | Apartment with rooms |
| Service | Network access | Doorbell |
| Pod | Running container | Room where app lives |

### 3. Deployment Strategies

| Strategy | Downtime | Risk | Best For |
|----------|----------|------|----------|
| **Rolling** | None | Low | Most apps (default) |
| **Blue-Green** | None | Low | Critical apps |
| **Canary** | None | Lowest | High-traffic apps |
| **Recreate** | YES | High | Dev/test only |


### 5. Authentication Pattern

```
Stage 1 (Harness Cloud):
  ├── Create ECR Repo     → Access keys (aws-cli on Harness Cloud needs them)
  └── BuildAndPushECR     → OIDC connector (no keys!) ✅

Stage 2 (EC2 via SSH / K8s Delegate):
  └── All steps           → EC2 IAM Role / K8s Delegate (no keys!) ✅
```

| Step | Auth Method | Why |
|------|-------------|-----|
| `Create ECR Repo` (Run step) | Access keys | Harness Cloud can't use OIDC for aws-cli env vars |
| `BuildAndPushECR` (native step) | OIDC connector | Harness native step supports OIDC directly |
| `Deploy Container` (commends) | EC2 IAM Role | Runs on EC2 via SSH, IAM role provides credentials |
| `kubectl apply` (ShellScript) | K8s Delegate | Delegate is inside EKS, has cluster access |

### 6. onDelegate: true vs false (ShellScript steps)

| | `onDelegate: true` | `onDelegate: false` |
|---|---|---|
| **Where script runs** | Inside delegate container | On the target host (via SSH) |
| **Has docker/aws?** | No (delegate is bare Java container) | Yes (EC2 host has everything installed) |
| **Needs SSH credential?** | No | Yes (uses infrastructure SSH config) |
| **Use case** | K8s delegate (has kubectl) | EC2/VM deployments (Secure Shell type) |

**`onDelegate: false` flow (Healthcare — EC2):**
```
Harness Cloud
    ↓ sends task
Docker Delegate (on EC2)
    ↓ delegate doesn't run script itself
    ↓ instead, SSHs into target host (using SSH credential)
    ↓
EC2 Host (script runs here)
    → has docker ✅
    → has aws-cli ✅
    → docker run, docker stop, etc.
```

**`onDelegate: true` flow (GoCart — EKS):**
```
Harness Cloud
    ↓ sends task
K8s Delegate (inside EKS cluster)
    ↓ delegate runs script inside its own container
    ↓
Delegate Container (script runs here)
    → has kubectl ✅ (pre-installed in K8s delegate)
    → kubectl apply, kubectl rollout, etc.
```

**Rule:**
- Secure Shell (`Ssh`) deployment → `onDelegate: false` (run on EC2 via SSH)
- Kubernetes deployment → `onDelegate: true` (run inside K8s delegate, has kubectl)

---

### 7. Resource Constraint (Traffic Light)

```
Harness prevents multiple deployments to the same infrastructure
at the same time (to avoid conflicts).

Without "Allow simultaneous":
  Pipeline Run #1 (deploying) → 🟢 Running
  Pipeline Run #2 (triggered) → 🔴 BLOCKED (waits for #1 to finish)
  Pipeline Run #2              → 🟢 Starts after #1 completes

With "Allow simultaneous":
  Pipeline Run #1 (deploying) → 🟢 Running
  Pipeline Run #2 (triggered) → 🟢 Running (both deploy at same time)
```

**For single EC2:** Keep it blocked (don't allow simultaneous) — you don't want two deployments running `docker stop` + `docker run` at the same time on the same server.

**If you see red light:** Go to Executions → Abort the old stuck/failed run → new run starts automatically.

---

## 🚀 Deployment Steps

### Two Topics in This Episode

| Topic | App | Delegate | Deploy Method | Access |
|-------|-----|----------|---------------|--------|
| **Topic 1** | Healthcare Website (HTML/CSS) | Docker Delegate (CD level) on EC2 | `docker run` | `http://EC2-IP` |
| **Topic 2** | GoCart E-Commerce (Next.js) | Kubernetes Delegate on EKS | `kubectl apply` | `http://LoadBalancer-URL` |

### Docker Delegate for CD (Different from Episode 3!)

```
Episode 3 (CI):                        Episode 6 (CD):
─────────────                          ─────────────
--network host   ✅ (for Runner)       No --network host
Tags: linux-amd64                      No tags
Docker Runner (port 3000)              No Runner needed
Purpose: Build code in containers      Purpose: Deploy containers
```

### Prerequisites (already done)

| What | Where | Episode | Link |
|------|-------|---------|------|
| GitHub connector (`account.Github`) | Account Settings → Connectors | Episode 1 | [Episode 1 — Deploy Steps](../Episode-01/hello-world-app/DEPLOY-STEPS.md) |
| AWS OIDC connector (`account.aws_account`) | Account Settings → Connectors | Episode 3 | [Episode 3 — Connector Setup](../Episode-03/README.md#connector-3-aws--🆕-create-now) |
| Secret: `aws_access_key_id` | Project Settings → Secrets | Episode 3 | [Episode 3 — Terraform README](../Episode-03/terraform-project/README.md#step-2-get-aws-access-key--secret-key) |
| Secret: `aws_secret_access_key` | Project Settings → Secrets | Episode 3 | [Episode 3 — Terraform README](../Episode-03/terraform-project/README.md#step-3-add-secrets-in-harness) |
| Variable: `aws_account_id` | Project Settings → Variables | Episode 4 | [Episode 4 — Deployment Steps](../Episode-04/README.md#step-1-add-aws-account-id-variable) |
| Variable: `aws_region` | Project Settings → Variables | Episode 3 | [Episode 3 — Terraform README](../Episode-03/terraform-project/README.md#step-4-add-variables-in-harness) |

### New Setup for Episode 6

**In Harness CD module UI (create manually before running pipeline):**

| # | What to Create | Where | Details |
|---|---------------|-------|---------|
| 1 | Service: `healthcare-website` | CD → Services | Type: Custom |
| 2 | Service: `gocart` | CD → Services | Type: Kubernetes, Manifests from Git, Artifact from ECR |
| 3 | Environment: `development` | CD → Environments | Type: Pre-Production |
| 4 | Infrastructure: `ec2-docker` | Inside `development` | Type: Custom, Delegate: `cd-docker-delegate` |
| 5 | Infrastructure: `eks-cluster` | Inside `development` | Type: Kubernetes, Inherit from Delegate |

See [Health care/DEPLOY-STEPS.md](./Health%20care/DEPLOY-STEPS.md) and [gocart/DEPLOY-STEPS.md](./gocart/DEPLOY-STEPS.md) for step-by-step.



## Comparison: Topic 1 vs Topic 2

| | Topic 1: Docker CD (EC2) | Topic 2: Kubernetes CD (EKS) |
|---|---|---|
| **App** | Healthcare Website (HTML/CSS) | GoCart E-Commerce (Next.js) |
| **Delegate** | Docker Delegate (no `--network host`, no tags, no Runner) | Kubernetes Delegate (installed from Bastion) |
| **Deploy** | `docker run` on EC2 | `kubectl apply` on EKS |
| **Database** | None (static site) | PostgreSQL (Docker image on K8s) |
| **Access** | `http://EC2-IP:80` | `http://LOADBALANCER-URL` |
| **Replicas** | 1 container | 2 pods |
| **Health Check** | HTTP 200 | readinessProbe + livenessProbe |
| **Rollback** | `docker stop new → docker start old` | `kubectl rollout undo` |
| **Best for** | Simple apps, dev/test | Production, scalable apps |

---

## 🧪 How to Test Rollback

### When Rollback Triggers vs Pipeline Stops

| What You Break | Stage 1 (Build) | Stage 2 (Deploy) | Rollback? |
|---------------|-----------------|-------------------|-----------|
| `requirements.txt` (bad package) | ❌ Install fails | Never runs | **No** — pipeline stops |
| `test_app.py` (fail a test) | ❌ Tests fail | Never runs | **No** — pipeline stops |
| `app.py` (syntax error like `erxtcfgvhbjkmle`) | ✅ Image builds | ❌ Flask crashes → health fails | **YES ✅** |
| `k8s/deployment.yaml` (invalid YAML) | ✅ Image builds | ❌ kubectl fails | **YES ✅** |

### Healthcare Website (Docker on EC2)

**Best test for rollback:**
1. Run pipeline → success → `:stable` tagged ✅
2. Add garbage text in `app.py` (like `erxtcfgvhbjkmle` on line 5)
3. Push → Run pipeline
4. Stage 1: Image builds fine ✅ (Python doesn't check syntax at build time)
5. Stage 2: Container starts → Flask crashes → `/health` no response → Health check FAILS → **Rollback triggers** → pulls `:stable` → old version back ✅

**Test pipeline STOP (no rollback):**
1. Add `invalid_package_xyz` in `requirements.txt`
2. Push → Run pipeline
3. Stage 1: Install Dependencies FAILS → pipeline STOPS
4. Stage 2: Never runs. Old deployment on EC2 stays untouched. No rollback.

---

### GoCart (Kubernetes on EKS)

| What to Break | Stage 1 | Stage 2 | Rollback? |
|---------------|---------|---------|-----------|
| `package.json` (invalid JSON) | ❌ Build fails | Never runs | No |
| `Dockerfile` (bad command) | ❌ Build fails | Never runs | No |
| **`k8s/deployment.yaml`** (invalid YAML) | ✅ Build passes | ❌ kubectl fails | **YES ✅** |
| **App runtime crash** (bad code) | ✅ Build passes | ❌ Health check fails | **YES ✅** |

**Best test for GoCart:**
1. Run pipeline → success ✅
2. Add garbage to `k8s/deployment.yaml` (like `dfghjk: invalid`)
3. Push → Run pipeline
4. Stage 1: Image builds fine (code is correct) ✅
5. Stage 2: `kubectl apply` fails on bad YAML → **Rollback triggers** → `kubectl rollout undo` → previous version restored ✅

---

Harness OIDC connector (aws_account) → Used in Episode 6, 7, 10 for deploying to EKS and pushing to ECR.

> 🎬 Next Episode: [Episode 7 - Helm, Amazon EKS & Amazon ECS Deployment](../Episode-07/README.md)
