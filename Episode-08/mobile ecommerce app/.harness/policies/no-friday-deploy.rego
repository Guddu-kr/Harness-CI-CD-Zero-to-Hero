# ============================================
# OPA Policy: No Deployments on Friday After 5 PM
# This policy blocks production deployments on Fridays
# after 5 PM to prevent weekend incidents.
#
# How to use in Harness:
#   1. Go to Project Settings → Governance → Policies
#   2. Create new policy with this Rego code
#   3. Create Policy Set → attach to pipeline
#   4. Set enforcement: "Error and Exit" (blocks pipeline)
# ============================================
package pipeline

# Deny deployment on Friday after 17:00 (5 PM)
deny[msg] {
    input.pipeline.stages[_].stage.type == "Deployment"
    time.now_ns() > 0
    day := time.weekday(time.now_ns())
    day == "Friday"
    hour := time.clock(time.now_ns())[0]
    hour >= 17
    msg := "Deployments to production are not allowed on Friday after 5 PM. Please deploy on Monday."
}

# Deny deployment without approval stage
deny[msg] {
    deployment_stages := [s | s := input.pipeline.stages[_]; s.stage.type == "Deployment"]
    count(deployment_stages) > 0
    approval_stages := [s | s := input.pipeline.stages[_]; s.stage.type == "Approval"]
    count(approval_stages) == 0
    msg := "Production deployments must have an Approval stage before the Deployment stage."
}
