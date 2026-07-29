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
