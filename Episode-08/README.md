## Episode 8: Enterprise Security & Governance

### App
**Mobile E-Commerce App** (React frontend + Node.js/Express backend + MongoDB)

### Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  EPISODE 8 FLOW                                                  │
│                                                                   │
│  Code Push → CI Pipeline                                         │
│    ├── Build & Test                                              │
│    ├── Security Scan (from Ep 5 — reuse)                        │
│    └── Push to ECR                                               │
│                                                                   │
│  CD Pipeline                                                      │
│    ├── OPA Policy Check ← "No deploy on Friday after 5 PM"      │
│    ├── Manual Approval Gate ← Manager must approve               │
│    ├── Deploy to EKS (Helm or K8s manifests)                    │
│    └── Secrets from AWS Secrets Manager (not hardcoded!)         │
│                                                                   │
│  NEW IN THIS EPISODE:                                            │
│    1. AWS Secrets Manager (store DB passwords, JWT secrets)      │
│    2. Approval Gates (Manual + optional Jira)                    │
│    3. OPA Policies (block deploys based on rules)                │
│    4. Encrypted Variables (Harness secrets, not plaintext)       │
└─────────────────────────────────────────────────────────────────┘
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

## 📝 Key Takeaways

1. **Never store secrets in code** → Use a secret manager
2. **AWS Secrets Manager** = Best for AWS teams (auto-rotation)
3. **HashiCorp Vault** = Best for multi-cloud (most features)
4. **Approval Gates** = Human checkpoint before risky actions
5. **OPA Policies** = Automatic rule enforcement (no humans needed)
6. **Defense in Depth** = Multiple layers of security

---

> 🎬 Next Episode: [Episode 9 - GitOps & Observability](../Episode-09/README.md)
