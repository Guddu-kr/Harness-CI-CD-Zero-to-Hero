variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name (used for all resource names)"
  type        = string
  default     = "online-shopping"
}

variable "container_port" {
  description = "Port the container listens on (Tomcat default)"
  type        = number
  default     = 8080
}

# ═══════════════════════════════════════════════════════════════════
# Harness Delegate Variables
# Get from: Harness → Project Settings → Delegates → Tokens
# ═══════════════════════════════════════════════════════════════════
variable "delegate_account_id" {
  description = "Harness Account ID (from Account Settings → Overview)"
  type        = string
  default     = ""
}

variable "delegate_token" {
  description = "Harness Delegate Token (from Project Settings → Delegates → Tokens)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "delegate_image_tag" {
  description = "Harness Delegate image tag (from Harness UI → Delegates → Install → Docker command)"
  type        = string
  default     = "26.07.89601"
}
