# Episode 9: GitOps & Observability — Deployment Steps

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  HARNESS CI + GITOPS PIPELINE                                     │
│                                                                    │
│  Stage 1: Build & Push (CI)                                       │
│  ┌────────────┐  ┌──────────┐  ┌──────────────────────┐          │
│  │ Composer   │→ │ PHPUnit  │→ │ BuildAndPushECR      │          │
│  │ Install    │  │ Tests    │  │ (OIDC, tag: seqId)   │          │
│  └────────────┘  └──────────┘  └──────────────────────┘          │
│                                                                    │
│  Stage 2: GitOps Deploy (CD — gitOpsEnabled: true)                │
│  ┌──────────────────┐  ┌──────────┐  ┌─────────┐  ┌──────────┐  │
│  │ UpdateReleaseRepo│→ │ Approval │→ │MergePR  │→ │GitOpsSync│  │
│  │ (update values,  │  │ (human)  │  │(merge to│  │(ArgoCD   │  │
│  │  create PR)      │  │          │  │ main)   │  │ syncs)   │  │
│  └──────────────────┘  └──────────┘  └─────────┘  └──────────┘  │
│         ↓                                                ↓        │
│  ┌──────────────────────┐                    ┌──────────────────┐ │
│  │ Harness Verify (CV)  │←───── after sync ──│ Compare metrics  │ │
│  └──────────────────────┘                    └──────────────────┘ │
│         ↓ (if verify fails)                                       │
│  ┌──────────────────────┐                                         │
│  │ Rollback GitOpsSync  │                                         │
│  └──────────────────────┘                                         │
│                                                                    │
├──────────────────────────────────────────────────────────────────┤
│  GITOPS AGENT (in EKS cluster)                                    │
│                                                                    │
│  Watches: GitHub repo → Episode-09/shop ecommerce app/k8s/       │
│  Action:  Auto-sync manifests to cluster after PR merged          │
│  Self-Heal: Reverts any manual drift                              │
│                                                                    │
├──────────────────────────────────────────────────────────────────┤
│  OBSERVABILITY STACK (in monitoring namespace)                    │
│                                                                    │
│  Prometheus → Scrapes /nginx-status every 15s                     │
│  Grafana    → Dashboards (CPU, Memory, Requests, Latency)        │
│  Alerts     → Slack/Email on: HighErrorRate, PodCrash, MySQLDown │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

### Harness GitOps Pipeline Steps (from [official docs](https://developer.harness.io/docs/continuous-delivery/gitops/pr-pipelines/gitops-pipeline-steps/))

| Step Type | Purpose |
|-----------|---------|
| `GitOpsUpdateReleaseRepo` | Fetches values.yaml, updates variables (image tag), commits, pushes, and creates a PR |
| `HarnessApproval` | Human approval before merging PR to main |
| `MergePR` | Merges the PR created by UpdateReleaseRepo |
| `GitOpsSync` | Triggers ArgoCD sync of the application (applies merged manifests to cluster) |
| `Verify` | Continuous Verification — compares pre/post deployment metrics |

Source: [harness-community/Gitops-Samples](https://github.com/harness-community/Gitops-Samples)

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

Wait 2 min → Harness UI → **Connected** ✅

---

## Step 3: Install Harness GitOps Agent

1. Go to **Harness → GitOps → Settings → GitOps Agents**
2. Click **+ New GitOps Agent**
3. **"Do you have any existing Argo CD or Flux instances?"** → Select **No** → Click **Start**
4. Fill in Overview:
   - **Name:** `gitopsagent`
   - **GitOps Operator:** Argo (default)
   - **Namespace:** `gitops`
   - **Namespaced:** unchecked
   - **Skip Crds:** unchecked
   - **High Availability:** OFF
5. Under **Advanced** (scroll down):
   - **Enable Helm Secrets Path Traversal:** ✅ Check (allows accessing secrets in Helm values from different paths)
   - **Enable ArgoCD Harness Plugin:** ✅ Check (required for `<+secrets.getValue()>` resolution)
   - Leave other Advanced settings empty
6. **Certificate / Proxy settings:** leave empty → Click **Continue**
7. **Disaster Recovery:** OFF → Click **Continue**
8. Harness shows **Helm install command** — copy it
9. On Bastion, run:

```bash
kubectl create namespace gitops
# Paste the Helm install command from Harness UI
```

10. Wait 2 min → Harness UI shows agent status: **Healthy** ✅


---

## Step 4: Install Observability Stack (Prometheus + Grafana + EFK + Jaeger)

> **Fully automated!** One pipeline deploys everything via ArgoCD App-of-Apps.
> No manual `helm install` or `kubectl apply` needed.

1. Go to **Pipelines → + Create Pipeline → Import from Git**
2. YAML Path: `Episode-09/shop ecommerce app/.harness/observability-infra-pipeline.yaml`
3. Click **Run Pipeline**
4. Wait ~5 minutes — ArgoCD syncs all 3 stacks from Git
5. Pipeline output shows 3 LoadBalancer URLs:

```
1. GRAFANA:  http://xxx.elb.amazonaws.com     (admin / admin123)
2. KIBANA:   http://xxx.elb.amazonaws.com     (elastic / HarnessEFK@2026)
3. JAEGER:   http://xxx.elb.amazonaws.com
```

> **How it works (ArgoCD App-of-Apps — MNC pattern):**
> - Pipeline applies 3 ArgoCD Application manifests
> - ArgoCD watches Git folders (monitoring/, logging/, tracing/)
> - Auto-syncs all manifests to cluster
> - Self-heal: if someone deletes a pod, ArgoCD recreates it
> - Repo URL + branch auto-detected from pipeline codebase (no YAML editing needed)
>
> **After this runs once, ArgoCD manages observability forever.**
> Any change to monitoring/logging/tracing manifests in Git → ArgoCD auto-applies.

---

## Step 5: Create GitOps Repository

1. Go to **Harness → GitOps → Settings → Repositories**
2. Click **+ New Repository**
3. Configure:
   - **Repository URL:** `https://github.com/YOUR-USER/Harness-CI-CD-Zero-to-Hero`
   - **Authentication:** GitHub PAT (use existing `account.Github` connector credentials)

---

## Step 6: Create GitOps Application

1. Go to **Harness → GitOps → Applications**
2. Click **+ New Application**
3. Configure:
   - **Name:** `shop-ecommerce`
   - **GitOps Agent:** (select agent from Step 3)
   - **Source:**
     - Repository: (select from Step 5)
     - Path: `Episode-09/shop ecommerce app/k8s/`
     - Target Revision: `master`
   - **Destination:**
     - Cluster: `https://kubernetes.default.svc` (in-cluster)
     - Namespace: `shop-ecommerce`
   - **Sync Policy:**
     - Auto-Sync: **Enabled**
     - Self-Heal: **Enabled**
     - Prune: **Enabled**
     - Create Namespace: **Enabled**

---

## Step 7: Create Secrets in Harness (Built-in Secret Manager)

1. Go to **Project Settings → Secrets → + New Secret → Text**
2. Secret Manager: **Harness Built-in Secret Manager** (default)
3. Create these secrets:

| Secret ID | Value |
|-----------|-------|
| `shop_app_key` | `base64:xxxxxxx` (run `php artisan key:generate --show`) |
| `shop_db_username` | `shop_user` |
| `shop_db_password` | (strong password) |
| `shop_stripe_key` | `pk_test_xxxxx` |
| `shop_stripe_secret` | `sk_test_xxxxx` |
| `shop_mail_host` | `smtp.gmail.com` or SES endpoint |
| `shop_mail_username` | (email) |
| `shop_mail_password` | (app password) |
| `slack_webhook_url` | `https://hooks.slack.com/services/xxx/xxx/xxx` |

---

## Step 8: Create Harness Service (GitOps)

> **Important:** For GitOps, the Service uses a **Release Repo Manifest** (not K8s Manifest). This tells the `GitOpsUpdateReleaseRepo` step which file to update.

1. Go to **Project Settings → Services → + New Service**
2. Configure:
   - **Name:** `shop-ecommerce`
   - **Deployment Type:** Kubernetes
   - **Select:** GitOps (checkbox)
   - **Manifests → + Add Release Repo Manifest:**
     - Release Repo Store: **GitHub**
     - GitHub Connector: `account.Github`
     - Repo: `Harness-CI-CD-Zero-to-Hero`
     - Branch: `main`
     - File Path: `Episode-09/shop ecommerce app/k8s/values.yaml`
   - **Artifact → + Add Artifact Source:**
     - Type: ECR
     - Identifier: `ecr_image`
     - Connector: `account.aws_account`
     - Region: `<+variable.aws_region>`
     - Image Path: `shop-ecommerce`
     - Tag: `<+input>`

> The `GitOpsUpdateReleaseRepo` step will update the `image` variable in `values.yaml` via a PR. ArgoCD then syncs the updated manifests.

Source: [Harness GitOps Service docs](https://developer.harness.io/docs/continuous-delivery/gitops/gitops-entities/service/)

---

## Step 9: Create Harness Environment + GitOps Cluster

**Environment:**
1. Go to **Project Settings → Environments → + New Environment**
2. **Name:** `production`
3. **Type:** Production

**Link GitOps Cluster to Environment:**
1. Open the `production` environment
2. Go to **GitOps Clusters** tab
3. Click **+ Select Cluster(s)**
4. Select the GitOps cluster from the agent installed in Step 3
   - Identifier: `shopcluster`
   - Agent: `gitopsagent`

> **Key difference from CD (Episodes 6-8):** In GitOps, there is NO Infrastructure Definition. Instead, you link GitOps Clusters directly to the Environment. The agent already knows which cluster to deploy to.

Source: [Harness GitOps Quickstart — Add Cluster](https://developer.harness.io/docs/continuous-delivery/gitops/get-started/harness-cd-git-ops-quickstart#step-3-add-a-harness-gitops-cluster)

---

## Step 10: Configure Slack Notifications

1. Create a Slack Incoming Webhook:
   - Go to your Slack workspace → Apps → Incoming Webhooks → Add
   - Choose channel (e.g., `#deployments`)
   - Copy the webhook URL

2. Add webhook URL as secret in Harness:
   - Secret ID: `slack_webhook_url`
   - Value: `https://hooks.slack.com/services/xxx/xxx/xxx`

---

## Step 11: Import Pipeline from Git

1. Go to **Pipelines → + Create Pipeline**
2. Select **Import from Git**
3. Configure:
   - Connector: `account.Github`
   - Repo: `Harness-CI-CD-Zero-to-Hero`
   - Branch: `main`
   - YAML Path: `Episode-09/shop ecommerce app/.harness/gitops-pipeline.yaml`

> **GitOps Pipeline Structure (2 stages):**
> - **Stage 1 (CI):** Build image → Push to ECR
> - **Stage 2 (CD — gitOpsEnabled: true):** UpdateReleaseRepo → Approval → MergePR → GitOpsSync → Verify
>
> The `gitOpsEnabled: true` flag tells Harness this is a GitOps deployment — it uses `gitOpsClusters` instead of `infrastructureDefinitions`.

### Pipeline Step Types Reference

| Step | Type | What It Does |
|------|------|-------------|
| Update Release Repo | `GitOpsUpdateReleaseRepo` | Updates `image` variable in `values.yaml`, commits to a branch, creates PR |
| Approve | `HarnessApproval` | Blocks pipeline until a team member approves |
| Merge PR | `MergePR` | Merges the PR into `main` branch (with `deleteSourceBranch: true`) |
| GitOps Sync | `GitOpsSync` | Triggers ArgoCD to sync application (applies manifests to cluster) |
| Verify | `Verify` | Queries Prometheus, compares pre/post metrics, auto-rollback if degraded |

Source: [Harness GitOps pipeline steps](https://developer.harness.io/docs/continuous-delivery/gitops/pr-pipelines/gitops-pipeline-steps/)

---

## Step 12: Run the Pipeline

1. Click **Run Pipeline**
2. Select branch: `main`
3. Watch the stages:

**Stage 1 (CI):**
- Installs Composer dependencies
- Runs PHPUnit tests
- Builds Docker image and pushes to ECR with tag `#<sequenceId>`

**Stage 2 (GitOps Deploy):**
- **UpdateReleaseRepo:** Updates `image` in `values.yaml` to new ECR URL, creates a PR
- **Approval:** Pipeline pauses — review the PR in GitHub, then approve in Harness
- **MergePR:** Merges PR into `main` (source branch auto-deleted)
- **GitOpsSync:** Triggers ArgoCD agent to sync — pulls merged `values.yaml`, applies manifests
- **Verify:** Monitors Prometheus metrics for 10 minutes, comparing to baseline

4. Check GitOps dashboard: Application shows **Synced ✅ Healthy ✅**
5. Get LoadBalancer URL:
   ```bash
   kubectl get svc shop-ecommerce-service -n shop-ecommerce
   ```
6. Open `http://EXTERNAL-IP` in browser to see the ecommerce app running

### What Happens Under the Hood

```
Pipeline runs → UpdateReleaseRepo creates PR with new image tag
       ↓
Human approves → MergePR merges to main
       ↓
GitOpsSync tells ArgoCD agent to sync NOW (vs waiting 3 min poll)
       ↓
ArgoCD detects values.yaml changed → renders templates → kubectl apply
       ↓
New pods start (rolling update: maxUnavailable: 0 = zero downtime)
       ↓
Verify step queries Prometheus: error_rate, latency, pod_restarts
       ↓
If healthy → Pipeline succeeds → Slack notification sent
```

---

## Step 13: Test GitOps Self-Heal

```bash
# Manually delete a pod (simulating drift)
kubectl delete pod -l app=shop-ecommerce -n shop-ecommerce

# Watch GitOps agent recreate it within seconds
kubectl get pods -n shop-ecommerce -w
```

The GitOps agent detects the drift and reconciles back to the Git-defined state.

---

## Step 14: Test Rollback

```bash
# Option 1: Revert Git commit
git revert HEAD
git push origin main
# GitOps agent auto-syncs to previous state

# Option 2: Manual sync to previous revision in Harness GitOps dashboard
# Applications → shop-ecommerce → History → Rollback to revision
```

---

## Step 15: Access Grafana Dashboards

```bash
kubectl get svc grafana -n monitoring
# Open: http://GRAFANA-LOADBALANCER-URL
# Login: admin / admin123
```

Import recommended dashboards:
- **Dashboard ID 6417** — Kubernetes Pods
- **Dashboard ID 1860** — Node Exporter Full
- **Dashboard ID 13332** — Nginx Ingress Controller

---

## Step 16: Cleanup

```bash
# Delete ArgoCD applications (this removes all observability pods)
kubectl delete application monitoring logging tracing -n gitops

# Delete GitOps application for the app
# Go to Harness UI → GitOps → Applications → Delete shop-ecommerce

# Delete namespaces (if ArgoCD didn't clean them)
kubectl delete namespace monitoring logging tracing shop-ecommerce

# Delete ECR repository
aws ecr delete-repository --repository-name shop-ecommerce --region us-east-1 --force

# Destroy EKS cluster (stop billing!)
# GitHub → Actions → "EKS Terraform" → destroy
```

---

## Notifications You'll Receive

| Event | Channel | Message |
|-------|---------|---------|
| Pipeline succeeds | Slack | "Pipeline Shop Ecommerce GitOps #N succeeded" |
| Pipeline fails | Slack | "Pipeline failed at stage X — view logs" |
| GitOps sync succeeds | Harness Dashboard | Application: Synced ✅ |
| GitOps drift detected | Harness Dashboard | Application: OutOfSync → Auto-healed |
| Alert fires (HighErrorRate) | Slack (via Alertmanager) | "CRITICAL: Error rate above 5%" |
| Pod crash looping | Slack (via Alertmanager) | "WARNING: Pod X restarting" |

---

## Key Concepts Demonstrated

| Concept | How It's Shown |
|---------|---------------|
| GitOps (Pull model) | Agent syncs from Git, no `kubectl apply` in pipeline |
| Self-Heal | Delete pod manually → agent recreates it |
| Auto-Sync | Push to Git → cluster updates within 3 min |
| Continuous Verification | Harness Verify compares pre/post metrics |
| Auto-Rollback | Verify fails → rollback GitOps sync |
| Prometheus Metrics | ServiceMonitor scrapes app every 15s |
| Grafana Dashboards | Visual CPU/Memory/Latency/Error graphs |
| Alert Rules | PrometheusRule fires on high errors/crashes |
| Notifications | Slack on pipeline and alert events |
| Secret Injection | `<+secrets.getValue()>` resolved by GitOps Agent plugin |


```
Step 1:  Create EKS Cluster
Step 2:  SSH + Install K8s Delegate
Step 3:  Install GitOps Agent (ArgoCD)
Step 4:  Install Observability (pipeline — uses ArgoCD from Step 3)
Step 5:  Create GitOps Repository
Step 6:  Create GitOps Application (uses agent from Step 3, repo from Step 5)
Step 7:  Create Secrets
Step 8:  Create Service (GitOps)
Step 9:  Create Environment + GitOps Cluster (uses agent from Step 3)
Step 10: Configure Slack
Step 11: Import App Pipeline
Step 12: Run Pipeline
Step 13: Test Self-Heal
Step 14: Test Rollback
Step 15: Access Grafana
Step 16: Cleanup
```