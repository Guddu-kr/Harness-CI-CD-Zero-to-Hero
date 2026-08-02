# 🚀 Episode 8 — Enterprise Security & Governance

## Flow

```
Build & Test → OPA Policy Check → Manual Approval → Deploy with Secrets
```

---

## Prerequisites (Already Done)

| What | Episode | Link |
|------|---------|------|
| GitHub connector (`account.Github`) | 1 | [Episode 1 — Step 3](../../Episode-01/hello-world-app/DEPLOY-STEPS.md#step-3-create-a-github-connector-first-time-only) |
| AWS OIDC connector (`account.aws_account`) | 3 | [Episode 3 — Connector 3](../../Episode-03/README.md#connector-3-aws--create-now) |
| Secret: `aws_access_key_id` | 3 | [Episode 3 — Step 2](../../Episode-03/terraform-project/README.md#step-2-get-aws-access-key--secret-key) |
| Secret: `aws_secret_access_key` | 3 | [Episode 3 — Step 3](../../Episode-03/terraform-project/README.md#step-3-add-secrets-in-harness) |
| Variable: `aws_account_id` | 4 | [Episode 4 — Step 1](../../Episode-04/README.md#step-1-add-variable-aws_account_id-in-harness) |
| Variable: `aws_region` | 3 | [Episode 3 — Step 4](../../Episode-03/terraform-project/README.md#step-4-add-variables-in-harness) |

---

## Step 1: Create EKS Cluster + Install Delegate

1. GitHub → Actions → **"EKS Terraform"** → Run workflow → `action: apply`
2. Wait ~12 minutes
3. Output: Bastion IP + Cluster name
4. SSH into Bastion:
   ```bash
   aws ssm start-session --target INSTANCE-ID --region us-east-1
   aws eks update-kubeconfig --region us-east-1 --name harness-eks-cluster
   kubectl get nodes
   ```
5. Install K8s Delegate:
   - Harness UI → Project Settings → **Delegates** → **+ New Delegate** → **Helm Chart**
   - Name: `eks-k8s-delegate`
   - On Bastion:
   ```bash
   helm repo add harness-delegate https://app.harness.io/storage/harness-download/delegate-helm-chart/
   helm repo update
   helm upgrade -i eks-k8s-delegate harness-delegate/harness-delegate-ng \
     --namespace harness-delegate-ng --create-namespace \
     --set delegateName=eks-k8s-delegate \
     --set accountId=YOUR_ACCOUNT_ID \
     --set delegateToken=YOUR_TOKEN \
     --set managerEndpoint=https://app.harness.io \
     --set delegateDockerImage=harness/delegate:latest \
     --set replicas=1 \
     --set upgrader.enabled=true
   kubectl get pods -n harness-delegate-ng
   ```
6. Wait 2 min → Harness UI → **Connected** ✅

---

## Step 2: Store Secrets in Harness Secret Manager

### Step 2.1: Create Secrets in Harness (Built-in Secret Manager)

1. Go to **Project Settings** → **Secrets** → **+ New Secret** → **Text**
2. Secret Manager: **Harness Built-in Secret Manager** (default)
3. Create 4 secrets:

| Secret Name | Value |
|---|---|
| `mongo_uri` | `mongodb://admin:admin123@mongodb:27017/ecommerce?authSource=admin` |
| `mongo_password` | `admin123` |
| `jwt_secret` | Any random string (e.g. `my-super-secret-jwt-key-2024`) |
| `jwt_refresh_secret` | Any random string (e.g. `my-refresh-secret-key-2024`) |

4. Click **Save** for each

> **How it works:**
> - Secrets are stored encrypted in Harness Built-in Secret Manager (Google KMS backed)
> - At deploy time: Harness resolves `<+secrets.getValue("mongo_uri")>` → injects into `values.yaml` → Go templating puts values into K8s Secret → deployed to cluster
> - Actual values NEVER appear in Git
> - Same `<+secrets.getValue()>` syntax works with ANY secret manager (Built-in, AWS SM, Vault)
>
> **Production note:** In real companies, you'd connect AWS Secrets Manager or HashiCorp Vault for rotation, audit trails, and compliance. The code/pipeline stays exactly the same — only the connector changes.

---

## Step 3: Create OPA Policies (Governance)

### What is OPA?

Open Policy Agent (OPA) lets organizations define rules as code. Instead of manually checking:
- Does every container have resource limits?
- Is someone deploying without approval?
- Is it Friday evening (risky for production)?

OPA evaluates these rules **automatically before deployment**. If a pipeline violates any policy, Harness **blocks the execution**.

### Step 3.1: Create Policy — No Friday Deploys

1. Go to **Project Settings** → **Governance** → **Policies**
2. Click **+ New Policy**
3. Name: `no-friday-deploy`
4. Paste the Rego code from `.harness/policies/no-friday-deploy.rego`
5. Click **Save**

### Step 3.2: Create Policy — K8s Governance

1. Click **+ New Policy**
2. Name: `k8s-governance`
3. Paste the Rego code from `.harness/policies/k8s-governance.rego`
4. Click **Save**

### Step 3.3: Create Policy Set

1. Go to **Policy Sets** → **+ New Policy Set**
2. Name: `production-governance`
3. Entity Type: **Pipeline**
4. Event: **On Run**
5. Add policies:
   - `no-friday-deploy` → Action: **Error and Exit**
   - `k8s-governance` → Action: **Warn and Continue**
6. Click **Save**

> **What each policy enforces:**
>
> | Policy | Rules |
> |--------|-------|
> | `no-friday-deploy` | No deploys on Friday after 5 PM, must have Approval stage |
> | `k8s-governance` | Must have CI stage before deploy, must have rollback, no hardcoded AWS IDs |

---

## Step 4: Create Service in Harness UI

### Step 4.1: Create Service + Add Manifests

1. Go to **Deployments** → **Services** → **+ New Service**
2. Name: `mobile-ecommerce` (ID: `mobileecommerce`)
3. Deployment Type: **Kubernetes**
4. **Manifests** → **+ Add Manifest**:
   - Manifest Type: **K8s Manifest**
   - Store: **GitHub**
   - Connector: `account.Github`
   - Repo: `Harness-CI-CD-Zero-to-Hero`
   - Branch: `master`
   - File/Folder Path: `Episode-08/mobile ecommerce app/k8s/`
   - Values YAML: `Episode-08/mobile ecommerce app/k8s/values.yaml`
### Step 4.2: Add Artifact Source (Backend — Primary)

1. Inside the service → **Artifacts** tab → **+ Add Artifact Source**
2. Choose: **Amazon ECR**
3. **Screen 1 (ECR Repository):**
   - Artifact Source Identifier: `ecr_backend`
   - Connector: `account.aws_account`
   - Region: `us-east-1`
4. **Screen 2 (Artifact Details):**
   - Image Path: `mobile-ecommerce-backend`
   - Tag: select **Runtime Input** (`<+input>`)
5. Click **Submit**
6. Click **Save** (top right)

> **Why only 1 artifact source?**
> Harness K8s service has ONE primary artifact (`<+artifact.image>`).
> - **Backend** → uses `<+artifact.image>` (resolved from this ECR artifact source)
> - **Frontend** → uses a constructed URL in `values.yaml`:
>   `<+variable.aws_account_id>.dkr.ecr.<+variable.aws_region>.amazonaws.com/mobile-ecommerce-frontend:v<+pipeline.sequenceId>`
>
> Both images get the same tag (`v1`, `v2`...) since they're built in the same pipeline run.

---

## Step 5: Create Environment + Infrastructure in Harness UI

### Step 5.1: Create Environment

1. Go to **Deployments** → **Environments** → **+ New Environment**
2. Fill in:
   - Name: `production`
   - Environment Type: **Production**
   - Setup: **Inline**
3. Click **Save**

### Step 5.2: Create Kubernetes Connector

1. Go to **Project Settings** → **Connectors** → **+ New Connector**
2. Choose: **Kubernetes Cluster**
3. **Screen 1 (Overview):**
   - Name: `k8s-delegate`
4. **Screen 2 (Details):**
   - Select: **Use the credentials of a specific Harness Delegate**
5. **Screen 3 (Delegates Setup):**
   - Select: **Connect only via Delegates which has all of the following tags**
   - Tag: `eks-k8s-delegate`
6. **Screen 4 (Connection Test):**
   - Click **Finish** → ✅ Connection Successful

### Step 5.3: Create Infrastructure Definition

1. Go to **Deployments** → **Environments** → click **`production`**
2. Under **Infrastructure Definitions** → **+ Infrastructure Definition**
3. Fill in:
   - Name: `k8s-delegate` (ID auto-generates: `k8sdelegate`)
   - Deployment Type: **Kubernetes**
   - Setup: **Inline**
4. **Cluster Details:**
   - Connector: select `k8s-delegate` (created in Step 5.2)
   - Namespace: `mobile-ecommerce`
5. Click **Save**

---

## Step 6: Push Code & Import Pipeline

```bash
git add .
git commit -m "Episode 8: Security & Governance"
git push origin master
```

Import: `Episode-08/mobile ecommerce app/.harness/pipeline-security-governance.yaml`

---

## Step 7: Run Pipeline

```
Stage 1: Build & Push ✅
  ├── Install Backend Dependencies
  ├── Backend Lint & Build Check
  ├── Install Frontend Dependencies
  ├── Frontend Build Check
  ├── Create ECR Repos
  ├── Push Backend to ECR
  └── Push Frontend to ECR

Stage 2: OPA Policy Evaluation ✅
  └── Evaluate Governance Policies (checks Policy Set: production-governance)

Stage 3: Manual Approval ⏸️ (click Approve)

Stage 4: Deploy to EKS ✅
  ├── K8sRollingDeploy (secrets injected from AWS SM at runtime)
  ├── Verify Deployment (kubectl get pods/svc)
  └── Rollback (auto on failure)
```

---

## What's NEW in This Episode

| Feature | What It Does | Where |
|---------|-------------|-------|
| **AWS Secrets Manager** | Secrets stored in AWS (rotation, audit, cross-account) | AWS Console + Harness Connector |
| **Secrets in K8s** | Injected at deploy time via values.yaml + Go templating | `values.yaml` → `secret.yaml` |
| **Approval Gate** | Pipeline pauses until someone clicks Approve | Stage 2 in pipeline |
| **OPA Policy** | Blocks Friday deploys, requires approval + CI stage | Governance → Policies |
| **Policy as Code** | Rules written in Rego, enforced automatically on every run | `.harness/policies/` |
| **Governance** | Standards every team must follow (no manual checking) | Policy Sets → On Run |

---

## Test OPA Policies

### Test 1: Remove Approval Stage
1. Edit pipeline → remove the `approval` stage
2. Try to run → OPA blocks: "Production deployments must have an Approval stage"
3. Add it back → runs normally ✅

### Test 2: Remove CI Stage
1. Edit pipeline → remove the `build-and-push` stage
2. Try to run → OPA warns: "Pipeline must include a CI stage before deployment"
3. Add it back → runs normally ✅

### Test 3: Friday After 5 PM
1. Wait until Friday after 5 PM (or set your system time)
2. Try to run → OPA blocks: "Deployments not allowed on Friday after 5 PM"
3. Run on Monday → works ✅

---

## Cleanup

> **Important:** Delete from Harness UI FIRST, then clean K8s + ECR.
> 1. Harness UI → Project Settings → Secrets → delete all 4 secrets
> 2. Then run the commands below

```bash
kubectl delete namespace mobile-ecommerce
aws ecr delete-repository --repository-name mobile-ecommerce-backend --force --region us-east-1
aws ecr delete-repository --repository-name mobile-ecommerce-frontend --force --region us-east-1
```
