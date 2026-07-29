# 🚀 Episode 7, Topic 1 — Deploy GoCart to EKS with Helm

## Flow

```
Reuse EKS Cluster → Reuse K8s Delegate → Create Helm Service → Import Pipeline → Run → LoadBalancer URL
```

---

## What Changed from Episode 6?

| | Episode 6 | Episode 7 |
|---|---|---|
| Manifests | Raw YAML files in `k8s/` | Helm chart in `helm/gocart/` |
| Configuration | Hardcoded in each YAML | `values.yaml` (change once, applies everywhere) |
| Deploy step | `K8sRollingDeploy` (raw manifests) | `K8sRollingDeploy` (Helm chart) |
| Multi-environment | Copy YAML files | Different `values-dev.yaml` / `values-prod.yaml` |
| Rollback | `K8sRollingRollback` | Same (Helm tracks revisions internally) |

---

## Prerequisites (Already Done)

| What | Episode | Link |
|------|---------|------|
| GitHub connector (`account.Github`) | 1 | [Episode 1 — Deploy Steps](../Episode-01/hello-world-app/DEPLOY-STEPS.md) |
| AWS OIDC connector (`account.aws_account`) | 3 | [Episode 3 — Connector Setup](../Episode-03/README.md#connector-3-aws--🆕-create-now) |
| Secret: `aws_access_key_id` | 3 | [Episode 3 — Terraform README](../Episode-03/terraform-project/README.md#step-2-get-aws-access-key--secret-key) |
| Secret: `aws_secret_access_key` | 3 | [Episode 3 — Terraform README](../Episode-03/terraform-project/README.md#step-3-add-secrets-in-harness) |
| Variable: `aws_account_id` | 4 | [Episode 4 — README](../Episode-04/README.md#step-1-add-variable-aws_account_id-in-harness) |
| Variable: `aws_region` | 3 | [Episode 3 — Terraform README](../Episode-03/terraform-project/README.md#step-4-add-variables-in-harness) |

---

## Step 1: Create EKS Cluster

1. GitHub → Actions → **"EKS Terraform"** → Run workflow → `action: apply`
2. Wait ~12 minutes
3. Output: Bastion IP + Cluster name

---

## Step 2: SSH into Bastion + Install K8s Delegate

```bash
aws ssm start-session --target INSTANCE-ID --region us-east-1

aws eks update-kubeconfig --region us-east-1 --name harness-eks-cluster
kubectl get nodes
```

Install delegate:
1. Harness UI → Project Settings → **Delegates** → **+ New Delegate** → **Helm Chart**
2. Name: `eks-k8s-delegate`
3. On Bastion, run:

```bash
helm repo add harness-delegate https://app.harness.io/storage/harness-download/delegate-helm-chart/
helm repo update

# Paste values from Harness UI
helm upgrade -i eks-k8s-delegate harness-delegate/harness-delegate-ng \
  --namespace harness-delegate-ng --create-namespace \
  --set delegateName=eks-k8s-delegate \
  --set accountId=YOUR_ACCOUNT_ID \
  --set delegateToken=YOUR_TOKEN \
  --set managerEndpoint=https://app.harness.io/gratis \
  --set delegateDockerImage=harness/delegate:latest \
  --set replicas=1 \
  --set upgrader.enabled=true

kubectl get pods -n harness-delegate-ng
```

Wait 2 min → Harness UI → **Connected** ✅

---

## Step 3: Create Service in Harness UI (Helm type)

1. CD → **Services** → **+ New Service**
2. Name: `gocart-helm` (ID auto-generates as `gocarthelm`)
3. Setup: **Inline**
4. Deployment Type: **Kubernetes**
5. **Manifests** → **+ Add Manifest**:
   - Type: **Helm Chart**
   - Helm Version: **V3**
   - Store: GitHub → Connector: `account.Github`
   - Repo: `Harness-CI-CD-Zero-to-Hero`
   - Manifest Identifier: `helm_chart`
   - Git Fetch Type: Latest from Branch
   - Branch: `master`
   - Chart Path: `Episode-07/gocart-helm/helm/gocart`
   - Values YAML: `values.yaml`
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

## Step 4: Create Environment + Infrastructure in Harness UI

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

## Step 5: Push Code to GitHub

```bash
git add .
git commit -m "Episode 7: GoCart Helm deployment"
git push origin master
```

---

## Step 6: Import Pipeline

1. CD → Pipelines → **+ Create a Pipeline** → **Import from Git**
2. Connector: `Github`
3. Repo: `Harness-CI-CD-Zero-to-Hero`
4. Branch: `master`
5. YAML Path: `Episode-07/gocart-helm/.harness/pipeline-helm-cd.yaml`
6. Import

---

## Step 7: Run Pipeline

```
Stage 1: Build & Push to ECR ✅
Stage 2: Deploy with Helm to EKS ✅
  ├── Helm Deploy (renders templates + kubectl apply)
  ├── Verify Deployment (pods + LoadBalancer)
  ├── Health Check (HTTP 200)
  └── Rollback (auto on failure):
      └── Helm Rollback (reverts to previous Helm revision)
```

---

## Step 8: Access GoCart

From Stage 2 logs, get LoadBalancer URL:
```
http://LOADBALANCER-URL
```

---

## Helm Chart Structure

```
helm/gocart/
├── Chart.yaml           ← Chart metadata (name, version)
├── values.yaml          ← Configuration (replicas, image, resources, postgres)
└── templates/
    ├── _helpers.tpl     ← Reusable template snippets
    ├── namespace.yaml   ← Namespace
    ├── secret.yaml      ← PostgreSQL + app secrets
    ├── configmap.yaml   ← App configuration
    ├── storageclass.yaml ← EBS storage for postgres
    ├── deployment.yaml  ← GoCart app (2 replicas, rolling update)
    ├── service.yaml     ← LoadBalancer (internet-facing)
    └── postgres.yaml    ← PostgreSQL + PVC + Service
```

---

## Why Helm > Raw Manifests (Production)

| Raw Manifests | Helm Chart |
|---|---|
| Hardcode values in each file | One `values.yaml` controls everything |
| Copy files for each environment | `values-dev.yaml`, `values-prod.yaml` |
| No versioning | Helm tracks revisions (rollback to any) |
| Manual templating | Go templates built-in |
| 7 files to manage | 1 chart to install |

---

## Cleanup

```bash
# From Bastion:
helm uninstall gocart -n gocart
kubectl delete namespace gocart
aws ecr delete-repository --repository-name gocart --force --region us-east-1
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "No eligible delegates" | Check K8s delegate: `kubectl get pods -n harness-delegate-ng` |
| Helm chart not found | Check Chart Path in Service matches `Episode-07/gocart-helm/helm/gocart` |
| values.yaml not found | Check Values YAML path in Service manifest config |
| Pods `ImagePullBackOff` | ECR image missing — check Stage 1 |
| No LoadBalancer URL | Wait 2-3 min for NLB provisioning |
