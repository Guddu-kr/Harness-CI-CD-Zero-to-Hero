# 🚀 Episode 8 — Enterprise Security & Governance

## Flow

```
Store Secrets → Create OPA Policy → Add Approval Gate → Deploy with Governance
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

## Step 2: Store Secrets in Harness (Secret Manager)

Go to **Project Settings → Secrets → + New Secret → Text**:

| Secret Name | Value |
|---|---|
| `mongo_uri` | `mongodb+srv://user:password@cluster.mongodb.net/ecommerce` |
| `jwt_secret` | Any random string (e.g. `my-super-secret-jwt-key-2024`) |
| `jwt_refresh_secret` | Any random string (e.g. `my-refresh-secret-key-2024`) |

> These secrets are stored encrypted in Harness. Never in Git. The pipeline reads them at deploy time via `<+secrets.getValue("mongo_uri")>`.

---

## Step 3: Create OPA Policy (Governance)

1. Go to **Project Settings → Governance → Policies**
2. Click **+ New Policy**
3. Name: `no-friday-deploy`
4. Paste the Rego code from `.harness/policies/no-friday-deploy.rego`
5. Save
6. Go to **Policy Sets** → **+ New Policy Set**
7. Name: `production-governance`
8. Entity Type: **Pipeline**
9. Event: **On Run**
10. Add policy: `no-friday-deploy` → Action: **Error and Exit**
11. Save

> Now if anyone tries to deploy on Friday after 5 PM → pipeline BLOCKED.

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
Stage 1: Build & Push Backend + Frontend to ECR ✅
Stage 2: Manual Approval ⏸️ (click Approve)
Stage 3: Deploy to EKS ✅
  ├── K8sRollingDeploy (secrets injected at runtime)
  ├── Verify Deployment
  └── Rollback (auto on failure)
```

---

## What's NEW in This Episode

| Feature | What It Does | Where |
|---------|-------------|-------|
| **Secrets** | MONGO_URI, JWT stored encrypted, never in Git | Project Settings → Secrets |
| **Approval Gate** | Pipeline pauses until someone clicks Approve | Stage 2 in pipeline |
| **OPA Policy** | Blocks Friday deploys, requires approval stage | Governance → Policies |
| **Secret Manager** | Harness built-in (can connect to AWS SM, Vault) | Account Settings → Secret Managers |

---

## Test OPA Policy

1. Remove the Approval stage from pipeline
2. Try to run → OPA blocks it: "Production deployments must have an Approval stage"
3. Add it back → runs normally ✅

---

## Cleanup

```bash
kubectl delete namespace mobile-ecommerce
aws ecr delete-repository --repository-name mobile-ecommerce-backend --force --region us-east-1
aws ecr delete-repository --repository-name mobile-ecommerce-frontend --force --region us-east-1
```
