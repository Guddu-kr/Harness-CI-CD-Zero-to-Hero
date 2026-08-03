# Episode 9: GitOps & Observability

## 🎯 Goal
Deploy using GitOps (Git controls everything) and monitor your apps with dashboards and alerts.
Like having a self-driving car (GitOps) with a full dashboard showing speed, fuel, engine health (Observability).

---

## 📚 Topics Covered

# Episode 9 — Production Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  CI STAGE (Harness Pipeline)                                     │
│                                                                   │
│  Clone → Composer Install → PHPUnit Tests → Docker Build         │
│  → Push to ECR (OIDC) → Update image tag in k8s/values.yaml     │
│  → Git commit + push (triggers GitOps sync)                      │
│                                                                   │
├─────────────────────────────────────────────────────────────────┤
│  GITOPS (No CD stage — Agent handles deployment)                 │
│                                                                   │
│  GitOps Agent detects new commit → Syncs k8s/ manifests          │
│  → Rolling update on EKS → Self-heal if drift                   │
│                                                                   │
├─────────────────────────────────────────────────────────────────┤
│  OBSERVABILITY                                                    │
│                                                                   │
│  Prometheus scrapes /metrics → Grafana dashboards                │
│  EFK collects logs → Kibana queries                              │
│  Harness Verify step compares pre/post deploy metrics            │
│  → Auto-rollback if degradation detected                         │
│                                                                   │
├─────────────────────────────────────────────────────────────────┤
│  NOTIFICATIONS                                                    │
│                                                                   │
│  Slack/Email/Teams on: sync success, sync failure, alert firing  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 1. What is GitOps?

```
┌─────────────────────────────────────────────────────────┐
│  TRADITIONAL CD (What we did in Episodes 6-7):          │
│                                                          │
│  Developer → Runs pipeline → Pipeline deploys to K8s    │
│  (PUSH model: Pipeline PUSHES changes to cluster)       │
│                                                          │
├─────────────────────────────────────────────────────────┤
│  GITOPS:                                                 │
│                                                          │
│  Developer → Commits to Git → Cluster PULLS changes     │
│  (PULL model: Cluster PULLS changes from Git)           │
│                                                          │
│  KEY DIFFERENCE:                                         │
│  Traditional: Pipeline has access to your cluster        │
│  GitOps: Cluster watches Git and updates itself         │
│                                                          │
│  ANALOGY:                                               │
│  Traditional = You drive to the store to get groceries  │
│  GitOps = Groceries auto-deliver when you add to list   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

### 2. GitOps Principles

```
┌─────────────────────────────────────────────────────────┐
│  THE 4 PRINCIPLES OF GITOPS                              │
│                                                          │
│  1. DECLARATIVE                                          │
│     Everything described as YAML in Git                  │
│     "I want 3 pods" not "create 3 pods"                 │
│                                                          │
│  2. VERSIONED AND IMMUTABLE                             │
│     Git history = complete audit trail                   │
│     Every change is tracked forever                      │
│                                                          │
│  3. PULLED AUTOMATICALLY                                 │
│     Agent in cluster watches Git                        │
│     Sees change → applies it automatically              │
│                                                          │
│  4. CONTINUOUSLY RECONCILED                              │
│     If someone manually changes cluster                 │
│     Agent detects drift → reverts to Git state          │
│     Git is ALWAYS the source of truth                   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Why GitOps is powerful:**
```
Scenario: Someone accidentally deletes a deployment
  
Traditional CD: 
  😱 "Who deleted it? Run the pipeline again!"
  
GitOps: 
  🤷 Agent detects drift → Auto-recreates from Git → Fixed in seconds!
```

---

### 3. Harness GitOps (Powered by Argo CD)

```
┌─────────────────────────────────────────────────────────┐
│  HARNESS GITOPS                                          │
│                                                          │
│  Under the hood: Argo CD (industry standard)            │
│  On top: Harness dashboard, governance, audit            │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │         HARNESS GITOPS ARCHITECTURE              │    │
│  │                                                   │    │
│  │  Git Repository (GitHub/GitLab)                  │    │
│  │       │                                           │    │
│  │       │ (watches for changes)                     │    │
│  │       ▼                                           │    │
│  │  Harness GitOps Agent (in your cluster)          │    │
│  │       │                                           │    │
│  │       │ (applies changes)                         │    │
│  │       ▼                                           │    │
│  │  Kubernetes Cluster                              │    │
│  │                                                   │    │
│  │  + Reports status back to Harness Dashboard      │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

### 4. Setting Up Harness GitOps

#### Step 1: Install GitOps Agent

```bash
# The GitOps agent runs in your cluster
# It watches Git repos and syncs to cluster

# Harness provides the install command:
kubectl create namespace gitops
kubectl apply -f https://app.harness.io/gitops/agent-install.yaml
```

#### Step 2: Create GitOps Application

```yaml
# GitOps Application = What to deploy + Where from + Where to
application:
  name: harness-course-app
  project: default
  source:
    repoURL: https://github.com/YOUR-USER/harness-cicd-sample-app
    path: k8s/              # folder with K8s manifests
    targetRevision: main    # Git branch to watch
  destination:
    server: https://kubernetes.default.svc
    namespace: harness-course
  syncPolicy:
    automated:
      prune: true          # Delete resources removed from Git
      selfHeal: true       # Fix manual changes (drift)
    syncOptions:
      - CreateNamespace=true
```

---

### 5. Sync, Rollback, and Auto-Sync

```
┌─────────────────────────────────────────────────────────┐
│  SYNC = Apply current Git state to cluster              │
│                                                          │
│  Manual Sync:  You click "Sync" in dashboard            │
│  Auto Sync:    Agent auto-applies when Git changes      │
│                                                          │
├─────────────────────────────────────────────────────────┤
│  ROLLBACK = Go back to previous Git commit              │
│                                                          │
│  How:                                                    │
│  1. Find the previous healthy commit in Git history     │
│  2. Click "Rollback" or revert the Git commit           │
│  3. Agent syncs to the old state                        │
│                                                          │
│  OR simply: git revert <bad-commit> && git push          │
│  Agent will auto-sync to the reverted state!            │
│                                                          │
├─────────────────────────────────────────────────────────┤
│  AUTO-SYNC                                               │
│                                                          │
│  prune: true                                            │
│  → If you delete a file from Git, K8s resource deleted  │
│                                                          │
│  selfHeal: true                                          │
│  → If someone manually changes cluster, auto-revert     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

### 6. GitOps Workflow in Practice

```
Developer's Workflow with GitOps:
═════════════════════════════════

1. Developer changes image tag in values.yaml:
   image:
     tag: "42"  →  tag: "43"

2. Creates Pull Request

3. Team reviews PR → Approves → Merges

4. GitOps agent detects change (within 3 minutes)

5. Agent applies new manifests to cluster

6. New pods start with image :43

7. Old pods gracefully terminate

8. Dashboard shows: Synced ✅

NO pipeline needed! Git IS the pipeline!
```

---

### 7. Observability Introduction

```
┌─────────────────────────────────────────────────────────┐
│  OBSERVABILITY = Can you see what's happening inside?   │
│                                                          │
│  Three Pillars:                                          │
│                                                          │
│  1. METRICS (Numbers over time)                          │
│     "CPU is at 80%", "100 requests/second"              │
│     Tool: Prometheus + Grafana                          │
│                                                          │
│  2. LOGS (Text records of events)                        │
│     "Error: Connection refused at 10:23 AM"             │
│     Tool: ELK Stack, Loki                               │
│                                                          │
│  3. TRACES (Request journey through services)            │
│     "Request took 2s: Auth(50ms) → DB(1.5s) → API"    │
│     Tool: Jaeger, Zipkin                                │
│                                                          │
│  ANALOGY:                                               │
│  Metrics = Car dashboard (speed, RPM, fuel)             │
│  Logs = Car's event recorder (what happened when)       │
│  Traces = GPS showing exact route taken                 │
└─────────────────────────────────────────────────────────┘
```

---

### 8. Prometheus (Metrics Collection)

```
┌─────────────────────────────────────────────────────────┐
│  PROMETHEUS                                              │
│                                                          │
│  What: Collects numbers (metrics) from your apps        │
│  How:  Scrapes /metrics endpoint every 15 seconds       │
│                                                          │
│  Your App exposes:                                       │
│  GET /metrics                                            │
│  → http_requests_total{method="GET", status="200"} 1542│
│  → http_request_duration_seconds{} 0.042                │
│  → jvm_memory_used_bytes{} 256000000                    │
│                                                          │
│  Prometheus stores these and you can query them!         │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Install Prometheus on Kubernetes:**
```bash
# Using Helm (easiest)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123
```

**Add metrics to Spring Boot (our app):**
```xml
<!-- pom.xml - Add Actuator + Prometheus -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

```yaml
# application.yml - Enable prometheus endpoint
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  metrics:
    export:
      prometheus:
        enabled: true
```

---

### 9. Grafana (Dashboards & Visualization)

```
┌─────────────────────────────────────────────────────────┐
│  GRAFANA                                                 │
│                                                          │
│  What: Beautiful dashboards for your metrics            │
│  Shows: Graphs, charts, alerts, all in one place        │
│                                                          │
│  Prometheus collects data → Grafana displays it          │
│  (Prometheus = security cameras, Grafana = TV monitors) │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │  GRAFANA DASHBOARD                               │    │
│  │                                                   │    │
│  │  CPU Usage    [████████░░] 78%                   │    │
│  │  Memory       [██████░░░░] 62%                   │    │
│  │  Requests/s   ▁▂▃▅▇█▇▅▃▂ (graph)               │    │
│  │  Error Rate   0.1%  ✅                           │    │
│  │  Latency p99  142ms ✅                           │    │
│  │  Pods Ready   3/3   ✅                           │    │
│  │                                                   │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Access Grafana:**
```bash
# Port forward to access locally
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring

# Open browser: http://localhost:3000
# Login: admin / admin123

# Import dashboard:
# Dashboard ID 6417 = Kubernetes Pods
# Dashboard ID 1860 = Node Exporter
```

---

### 10. Datadog & New Relic (Cloud Monitoring)

```
┌─────────────────────────────────────────────────────────┐
│  PROMETHEUS + GRAFANA  vs  DATADOG/NEW RELIC            │
│                                                          │
│  Prometheus + Grafana:                                   │
│  ✅ Free and open source                                │
│  ✅ Full control                                        │
│  ❌ You manage it yourself                              │
│  ❌ More setup work                                     │
│  Best for: Teams with K8s expertise                     │
│                                                          │
│  Datadog / New Relic:                                    │
│  ✅ Zero setup (install agent, done)                    │
│  ✅ Beautiful dashboards out-of-box                     │
│  ✅ AI-powered alerts                                   │
│  ❌ Expensive ($15-30 per host/month)                   │
│  ❌ Data lives in their cloud                           │
│  Best for: Teams that want it "just working"            │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Datadog Agent on K8s:**
```bash
helm repo add datadog https://helm.datadoghq.com
helm install datadog datadog/datadog \
  --set datadog.apiKey=<YOUR_API_KEY> \
  --set datadog.site='datadoghq.com' \
  --namespace monitoring
```

**New Relic on K8s:**
```bash
helm repo add newrelic https://helm-charts.newrelic.com
helm install newrelic newrelic/nri-bundle \
  --set global.licenseKey=<YOUR_LICENSE_KEY> \
  --set global.cluster=harness-course-cluster \
  --namespace monitoring
```

---

### 11. Harness Continuous Verification

```
┌─────────────────────────────────────────────────────────┐
│  HARNESS CONTINUOUS VERIFICATION                         │
│                                                          │
│  What: Harness automatically checks if deployment is OK │
│  How:  Connects to Prometheus/Datadog/New Relic         │
│        Compares metrics BEFORE and AFTER deployment     │
│        If metrics degrade → AUTO ROLLBACK               │
│                                                          │
│  Example:                                                │
│  Before deploy: Error rate = 0.1%                       │
│  After deploy:  Error rate = 5.0% ← BAD!              │
│  Harness: "Metrics degraded! Rolling back..."          │
│                                                          │
│  No human needed! Harness catches problems for you!     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Verify Step in Pipeline:**
```yaml
- step:
    type: Verify
    name: Verify Deployment Health
    identifier: verify
    timeout: 15m
    spec:
      type: Rolling
      monitoredService:
        type: Default
        spec: {}
      spec:
        sensitivity: MEDIUM
        duration: 10m
        deploymentTag: <+pipeline.sequenceId>
```

---

### 12. Notifications

#### Slack Notifications
```yaml
# In pipeline: Notify on success/failure
notificationRules:
  - name: Pipeline Notifications
    enabled: true
    pipelineEvents:
      - type: PipelineSuccess
      - type: PipelineFailed
      - type: StageSuccess
        forStages:
          - deploy_prod
    notificationMethod:
      type: Slack
      spec:
        webhookUrl: <+secrets.getValue("slack_webhook_url")>
    conditions:
      - type: AllEvents
```

**Slack message looks like:**
```
┌─────────────────────────────────────────────┐
│  🟢 Pipeline Succeeded                       │
│                                              │
│  Pipeline: Enterprise Deploy                 │
│  Build: #43                                  │
│  Stage: Deploy to Production ✅              │
│  Duration: 8m 32s                            │
│  Triggered by: yaswanth@company.com          │
│                                              │
│  [View Pipeline] [View Logs]                 │
└─────────────────────────────────────────────┘
```

#### Email Notifications
```yaml
notificationMethod:
  type: Email
  spec:
    recipients:
      - team@company.com
      - manager@company.com
```

#### Microsoft Teams Notifications
```yaml
notificationMethod:
  type: MsTeams
  spec:
    webhookUrl: <+secrets.getValue("teams_webhook_url")>
```

---

## 🖥️ Demo: GitOps Deployment + Monitoring

### Part 1: Set Up GitOps

1. **Enable GitOps** in your Harness project
2. **Install GitOps Agent:**
   ```bash
   # From Harness: GitOps → Settings → GitOps Agents → + New Agent
   # Download and apply the YAML
   kubectl apply -f gitops-agent.yaml -n gitops
   ```
3. **Create Repository** connection:
   - URL: Your GitHub repo
   - Auth: GitHub PAT
4. **Create Application:**
   - Name: `harness-course-app`
   - Source: GitHub repo, path `k8s/`, branch `main`
   - Destination: Cluster, namespace `harness-course`
   - Sync Policy: Automated + Self-Heal

### Part 2: Test GitOps Flow

```bash
# 1. Change image tag in your Git repo
# Edit k8s/deployment.yaml → change image tag to new version

# 2. Commit and push
git add .
git commit -m "Deploy version 43"
git push

# 3. Watch the GitOps dashboard
# Within 3 minutes, agent detects change
# New pods start rolling out
# Dashboard shows: Synced ✅
```

### Part 3: Set Up Monitoring

```bash
# Install Prometheus + Grafana
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

# Verify
kubectl get pods -n monitoring

# Access Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
```

### Part 4: Create Alerts

```yaml
# Prometheus Alert Rule
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-alerts
  namespace: monitoring
spec:
  groups:
    - name: app.rules
      rules:
        - alert: HighErrorRate
          expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "High error rate detected"
            description: "Error rate is above 5% for 2 minutes"
        
        - alert: PodCrashLooping
          expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod is crash looping"
```

---

## ✅ Episode 9 Checklist

- [ ] Understand what GitOps is (Git = source of truth)
- [ ] Know the 4 GitOps principles
- [ ] Understand Harness GitOps (Argo CD under the hood)
- [ ] Installed GitOps agent
- [ ] Created GitOps application
- [ ] Tested sync, rollback, and auto-sync
- [ ] Understand observability (metrics, logs, traces)
- [ ] Installed Prometheus on Kubernetes
- [ ] Set up Grafana dashboards
- [ ] Know Datadog and New Relic options
- [ ] Understand Harness Continuous Verification
- [ ] Configured Slack notifications
- [ ] Configured email notifications
- [ ] Created alerting rules

---

## 📝 Key Takeaways

1. **GitOps = Git is the single source of truth** (change Git → cluster updates)
2. **Self-heal** = cluster auto-reverts manual changes (no drift!)
3. **Prometheus** = Collects metrics, **Grafana** = Displays them beautifully
4. **Harness Verify** = Auto-rollback if metrics degrade after deployment
5. **Notifications** = Know immediately when something happens (Slack/Email/Teams)
6. **Observability is NOT optional** for production systems

---

> 🎬 Next Episode: [Episode 10 - Complete Enterprise Project (End-to-End)](../Episode-10/README.md)
