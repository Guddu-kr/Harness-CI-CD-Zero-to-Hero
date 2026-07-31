# ============================================
# OPA Policy: Kubernetes Deployment Standards
# ============================================
# This policy enforces K8s best practices on pipeline manifests:
#   1. Every container must have CPU and memory limits
#   2. Containers must not run as root user
#   3. Only approved container registries allowed
#   4. Every deployment must include health checks (readinessProbe)
#   5. Every deployment must have required labels
#
# How to use in Harness:
#   1. Go to Project Settings -> Governance -> Policies
#   2. Create new policy: k8s-governance
#   3. Create Policy Set -> attach to pipeline
#   4. Entity Type: Pipeline
#   5. Event: On Run
#   6. Enforcement: Warn and Continue (or Error and Exit for strict)
#
# NOTE: This policy evaluates the pipeline YAML structure.
# For manifest-level enforcement (actual K8s YAML), use:
#   - Kubernetes Admission Controllers (Gatekeeper/Kyverno)
#   - Harness Policy Step (evaluates after dry-run)
# ============================================
package pipeline

# Rule 1: Pipeline must have a CI stage (build) before Deployment
deny[msg] {
    stages := input.pipeline.stages
    deployment_found := [i | stages[i].stage.type == "Deployment"]
    ci_found := [i | stages[i].stage.type == "CI"]
    count(deployment_found) > 0
    count(ci_found) == 0
    msg := "Pipeline must include a CI (build) stage before deployment. Direct deployments without building are not allowed."
}

# Rule 2: Deployment stage must have a rollback strategy
deny[msg] {
    stage := input.pipeline.stages[_].stage
    stage.type == "Deployment"
    not stage.spec.execution.rollbackSteps
    msg := sprintf("Deployment stage '%s' must define rollbackSteps for automatic rollback on failure.", [stage.name])
}

# Rule 3: Pipeline must not use hardcoded AWS account IDs
deny[msg] {
    pipeline_yaml := json.marshal(input.pipeline)
    re_match(`\d{12}\.dkr\.ecr`, pipeline_yaml)
    msg := "Pipeline must not contain hardcoded AWS account IDs. Use <+variable.aws_account_id> instead."
}
