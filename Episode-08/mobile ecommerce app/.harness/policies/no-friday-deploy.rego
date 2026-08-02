# ============================================
# OPA Policy: Production Deployment Governance
# ============================================
# This policy enforces enterprise security standards:
#   1. No deployments on Friday after 5 PM (prevent weekend incidents) Friday after 5 PM (17:00 - 23:59)
#   2. Production deployments must have an Approval stage
#
# How to use in Harness:
#   1. Go to Project Settings -> Governance -> Policies
#   2. Create new policy with this Rego code
#   3. Create Policy Set -> attach to pipeline
#   4. Entity Type: Pipeline
#   5. Event: On Run
#   6. Enforcement: Error and Exit (blocks pipeline)
# ============================================
package pipeline

# Rule 1: Deny deployment on Friday after 5 PM (17:00 - 23:59)
deny[msg] {
    input.pipeline.stages[_].stage.type == "Deployment"
    time.now_ns() > 0
    day := time.weekday(time.now_ns())
    day == "Friday"
    hour := time.clock(time.now_ns())[0]
    hour >= 17
    msg := "Deployments to production are not allowed on Friday after 5 PM. Please deploy on Monday."
}

# Rule 2: Deny deployment without approval stage
deny[msg] {
    deployment_stages := [s | s := input.pipeline.stages[_]; s.stage.type == "Deployment"]
    count(deployment_stages) > 0
    approval_stages := [s | s := input.pipeline.stages[_]; s.stage.type == "Approval"]
    count(approval_stages) == 0
    msg := "Production deployments must have an Approval stage before the Deployment stage."
}
