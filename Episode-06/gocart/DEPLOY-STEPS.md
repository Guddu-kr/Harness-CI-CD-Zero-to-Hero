# 🚀 Episode 6, Topic 2 — Deploy GoCart to EKS (Kubernetes)

## Flow

```
Create EKS → Install K8s Delegate → Create Service + Environment → Import Pipeline → Run → LoadBalancer URL
```

---

## Prerequisites (Already Done)

| What | Episode |
|------|---------|
| GitHub connector (`account.Github`) | 1 |
| AWS OIDC connector (`account.aws_account`) | 3 |
| Secret: `aws_access_key_id` | 3 |
| Secret: `aws_secret_access_key` | 3 |
| Variable: `aws_account_id` | 4 |
| Variable: `aws_region` | 3 |

---

## Step 1: Create EKS Cluster

1. GitHub → Actions → **"EKS Terraform"** → Run workflow → `action: apply`
2. Wait ~15 minutes
3. Output: Bastion IP + Cluster name

---

## Step 2: SSH into Bastion + Connect to EKS

```bash
aws ssm start-session --target INSTANCE-ID --region us-east-1
# OR
ssh -i harness-bastion-key.pem ec2-user@BASTION-IP

aws eks update-kubeconfig --region us-east-1 --name harness-eks-cluster
kubectl get nodes
```

---

## Step 3: Install Kubernetes Delegate

1. Harness UI → Project Settings → **Delegates** → **+ New Delegate** → **Helm Chart**
2. Name: `eks-k8s-delegate`
3. Copy the Helm install command shown in Harness UI
4. On Bastion, run:

```bash
# Add Harness Helm repo
helm repo add harness-delegate https://app.harness.io/storage/harness-download/delegate-helm-chart/
helm repo update

# Install delegate (paste values from Harness UI)
helm upgrade -i eks-k8s-delegate harness-delegate/harness-delegate-ng \
  --namespace harness-delegate-ng --create-namespace \
  --set delegateName=eks-k8s-delegate \
  --set accountId=YOUR_ACCOUNT_ID \
  --set delegateToken=YOUR_TOKEN \
  --set managerEndpoint=https://app.harness.io/gratis \
  --set delegateDockerImage=harness/delegate:latest \
  --set replicas=1 \
  --set upgrader.enabled=true

# Verify
kubectl get pods -n harness-delegate-ng
```

Wait 2 min → Harness UI → **Connected** ✅

---

## Step 4: Create Service in Harness UI

1. CD → **Services** → **+ New Service**
2. Name: `gocart` (ID auto-generates as `gocart`)
3. Setup: **Inline**
4. Deployment Type: **Kubernetes**
5. **Manifests** → **+ Add Manifest**:
   - Type: K8s Manifest
   - Store: GitHub → Connector: `account.Github`
   - Repo: `Harness-CI-CD-Zero-to-Hero`
   - Manifest Identifier: `k8s_manifests`
   - Git Fetch Type: Latest from Branch
   - Branch: `master`
   - File/Folder Path: `Episode-06/gocart/k8s/`
   - Submit
6. **Artifacts** → **+ Add Artifact Source**:
   - Artifact Repository Type: **ECR**
   - Connector: `account.aws_account`
   - Artifact Source Identifier: `ecr_image`
   - Region: `us-east-1` (your region)
   - Registry ID: leave empty
   - Image Path: `gocart`
   - Tag: **Value** → `<+input>`
   - Submit
7. Save

---

## Step 5: Create Environment + Infrastructure in Harness UI

1. CD → **Environments** → **+ New Environment**
2. Name: `development`
3. Environment Type: **Pre-Production**
4. Setup: **Inline**
5. Save
6. Inside `development` → **+ Infrastructure Definition**
7. Name: `k8s-delegate` (ID auto-generates as `k8sdelegate`)
8. Deployment Type: **Kubernetes**
9. Setup: **Inline**
10. Infrastructure Type: **Direct Connection → Kubernetes**
11. Connector: **+ New Connector** → Kubernetes Cluster
    - Name: `k8s-delegate`
    - Details: **Use the credentials of a specific Harness Delegate**
    - Delegates Setup: Select `eks-k8s-delegate` tag
    - Connection Test: ✅
    - Save
12. Select connector: `k8s-delegate`
13. Namespace: `gocart`
14. Save

---

## Step 6: Push Code to GitHub

```bash
git add .
git commit -m "Episode 6: GoCart K8s CD"
git push origin master
```

---

## Step 7: Import Pipeline (in CD module)

1. CD → Pipelines → **+ Create a Pipeline** → **Import from Git**
2. Select: **Third-party Git provider**
3. Connector: `Github`
4. Repo: `Harness-CI-CD-Zero-to-Hero`
5. Branch: `master`
6. YAML Path: `Episode-06/gocart/.harness/pipeline-k8s-cd.yaml`
7. Import

---

## Step 8: Run Pipeline

```
Stage 1: Build & Push to ECR ✅
Stage 2: Deploy to EKS (CD Deployment stage) ✅
  ├── K8sRollingDeploy (Harness native — applies all K8s manifests)
  ├── Verify Deployment (pods + LoadBalancer)
  ├── Health Check (HTTP 200)
  └── Rollback (auto on failure):
      └── K8sRollingRollback (reverts to previous revision)
Stage 3: Approval ⏸️
Stage 4: Cleanup ✅
```

---

## Step 9: Access GoCart

From Stage 2 logs, get LoadBalancer URL:
```
http://LOADBALANCER-URL
```

Open in browser → GoCart E-Commerce UI ✅

---

## Test Rollback

1. Run pipeline → success ✅
2. Break `k8s/deployment.yaml` (add `dfghjk: invalid`)
3. Push → Run pipeline
4. Stage 1 passes ✅
5. Stage 2: `K8sRollingDeploy` fails → **K8sRollingRollback** auto-triggers ✅

---

## Verify from Bastion

```bash
kubectl get pods -n gocart
kubectl get svc -n gocart
kubectl rollout history deployment/gocart -n gocart
```

---

## Cleanup

```bash
# Pipeline does this after approval
# Or manually:
kubectl delete namespace gocart
aws ecr delete-repository --repository-name gocart --force --region us-east-1

# Destroy EKS (stop billing!):
# GitHub → Actions → "EKS Terraform" → destroy → confirm_destroy: yes
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "No eligible delegates" | `kubectl get pods -n harness-delegate-ng` |
| "Service not found" | Create `gocart` in Services UI |
| "Environment not found" | Create `development` in Environments UI |
| "Infrastructure not found" | Create `k8s-delegate` inside development |
| Pods `ImagePullBackOff` | ECR image missing — check Stage 1 |
| Pods `CrashLoopBackOff` | `kubectl logs deployment/gocart -n gocart` |
| No LoadBalancer URL | Wait 2-3 min |
| `<+artifact.image>` InvalidImageName | Service artifact not configured — see below |
| PVC unbound / no StorageClass | Run Step 9.5 above |


