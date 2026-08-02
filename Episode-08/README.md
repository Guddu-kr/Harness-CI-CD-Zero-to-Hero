## Episode 8: Enterprise Security & Governance

### App
**Mobile E-Commerce App** (React frontend + Node.js/Express backend + MongoDB)

### Pipeline Flow

```
Stage 1: Build & Push (CI) — parallel
  ├── [parallel] Backend Build Check | Frontend Build Check
  ├── Create ECR Repos
  └── [parallel] Push Backend | Push Frontend

Stage 2: OPA Policy Evaluation (Custom)
  └── Evaluate production-governance Policy Set

Stage 3: Manual Approval
  └── Approve Deployment (1 approver from project users)

Stage 4: Deploy to EKS (CD)
  ├── K8sRollingDeploy
  ├── Verify Deployment
  └── Rollback (auto on failure)

```

### Topics to Cover

| # | Topic | What You'll Do |
|---|-------|---------------|
| 1 | **AWS Secrets Manager** | Store MONGO_URI, JWT_SECRET in AWS → Harness reads at deploy time |
| 2 | **Harness Secret Manager** | Connect Harness to AWS Secrets Manager |
| 3 | **Encrypted Variables** | Reference secrets in pipeline without exposing values |
| 4 | **Manual Approval Gate** | Pipeline pauses → someone approves → then deploys |
| 5 | **OPA Policy** | Block deploys to prod without approval, or on weekends |
| 6 | **Policy as Code** | Write governance rules in Rego language |

### What You Need to Build

1. **Dockerfiles** (frontend + backend — separate containers)
2. **K8s manifests or Helm chart** (deploy to EKS)
3. **Harness pipeline** with:
   - CI: Build + Test + Push ECR
   - CD: OPA check → Approval → Deploy (secrets from AWS SM)
4. **OPA Policy** (Rego file)
5. **DEPLOY-STEPS.md**

### Infrastructure
- Reuse **EKS cluster** from Episode 6/7 (same `infra.yml`)
- Same K8s Delegate


---

## Step 2: Store Secrets in AWS Secrets Manager

### Step 2.1: Create AWS Secrets Manager Connector (via Secrets path)

1. Go to **Project Settings** → **Secrets** → **+ New Secret** → **Text**
2. Click on **Secret Manager** dropdown → **+ Secret Manager**
3. Select: **AWS Secrets Manager**
4. **Screen 1 (Overview):**
   - Name: `aws-secrets-manager`
5. **Screen 2 (Details):**
   - Credential Type: **Assume IAM role on Delegate**
   - Secret Name Prefix: `harness/`
   - Region: `us-east-1`
   - Check: **Force delete without recovery** ✅
6. **Screen 3 (Delegates Setup):**
   - Select: **Connect only via Delegates which has all of the following tags**
   - Tag: `eks-k8s-delegate`
7. **Screen 4 (Connection Test):**
   - Click **Finish** → ✅ Success

> **Why "Assume IAM role on Delegate"?**
> - No access keys stored anywhere — zero credentials to rotate
> - The K8s delegate runs on EKS node which has IAM role with AWS access
> - Delegate's IAM role accesses AWS Secrets Manager directly
> - Production standard: no long-lived keys, automatic rotation

### Step 2.2: Create Secrets in Harness (stored in AWS SM)

1. Go to **Project Settings** → **Secrets** → **+ New Secret** → **Text**
2. Select **Secret Manager**: `aws-secrets-manager`
3. Create 4 secrets:

| Secret Name | Value |
|---|---|
| `mongo_uri` | `mongodb://admin:admin123@mongodb:27017/ecommerce?authSource=admin` |
| `mongo_password` | `admin123` |
| `jwt_secret` | Any random string (e.g. `my-super-secret-jwt-key-2024`) |
| `jwt_refresh_secret` | Any random string (e.g. `my-refresh-secret-key-2024`) |

4. Click **Save** for each

> **How it works:**
> - When you create a secret and select `aws-secrets-manager` → Harness **automatically stores it in AWS Secrets Manager**
> - At deploy time: Harness reads from AWS SM → injects into `values.yaml` → Go templating puts values into K8s Secret → deployed to cluster
> - Actual values NEVER appear in Git
> - **Force delete without recovery** = you can delete and recreate secrets instantly (no 7-day wait)
>
> **Why AWS Secrets Manager?**
> Rotation, audit trail (CloudTrail), cross-account access, compliance (SOC2, HIPAA). Production teams use external secret managers.
---

## 📝 Key Takeaways

1. **Never store secrets in code** → Use a secret manager
2. **AWS Secrets Manager** = Best for AWS teams (auto-rotation)
3. **HashiCorp Vault** = Best for multi-cloud (most features)
4. **Approval Gates** = Human checkpoint before risky actions
5. **OPA Policies** = Automatic rule enforcement (no humans needed)
6. **Defense in Depth** = Multiple layers of security

---

> 🎬 Next Episode: [Episode 9 - GitOps & Observability](../Episode-09/README.md)
