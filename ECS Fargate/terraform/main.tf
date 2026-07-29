# ═══════════════════════════════════════════════════════════════════
# ECS Fargate Infrastructure for Blue-Green Deployment
# Creates: VPC, Subnets, ALB, 2 Target Groups, ECS Cluster, IAM Roles
# ═══════════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

# ═══════════════════════════════════════════════════════════════════
# VPC
# ═══════════════════════════════════════════════════════════════════
resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.app_name}-vpc" }
}

# ═══════════════════════════════════════════════════════════════════
# Internet Gateway
# ═══════════════════════════════════════════════════════════════════
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.app_name}-igw" }
}

# ═══════════════════════════════════════════════════════════════════
# Public Subnets (2 AZs — required for ALB)
# ═══════════════════════════════════════════════════════════════════
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.app_name}-public-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = { Name = "${var.app_name}-public-2" }
}

# ═══════════════════════════════════════════════════════════════════
# Route Table (public subnets → internet)
# ═══════════════════════════════════════════════════════════════════
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.app_name}-public-rt" }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ═══════════════════════════════════════════════════════════════════
# Security Group — ALB (allows HTTP from internet)
# ═══════════════════════════════════════════════════════════════════
resource "aws_security_group" "alb" {
  name        = "${var.app_name}-alb-sg"
  description = "ALB - allows HTTP from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Production traffic (port 80)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Test traffic for Blue-Green (port 8080)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-alb-sg" }
}

# ═══════════════════════════════════════════════════════════════════
# Security Group — ECS Tasks (allows traffic from ALB only)
# ═══════════════════════════════════════════════════════════════════
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.app_name}-ecs-sg"
  description = "ECS tasks - allows traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.app_name}-ecs-sg" }
}

# ═══════════════════════════════════════════════════════════════════
# Application Load Balancer (internet-facing)
# ═══════════════════════════════════════════════════════════════════
resource "aws_lb" "main" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = { Name = "${var.app_name}-alb" }
}

# ═══════════════════════════════════════════════════════════════════
# Target Group — BLUE (production traffic goes here)
# ═══════════════════════════════════════════════════════════════════
resource "aws_lb_target_group" "blue" {
  name        = "${var.app_name}-blue-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = { Name = "${var.app_name}-blue-tg" }
}

# ═══════════════════════════════════════════════════════════════════
# Target Group — GREEN (new version deployed here for testing)
# ═══════════════════════════════════════════════════════════════════
resource "aws_lb_target_group" "green" {
  name        = "${var.app_name}-green-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = { Name = "${var.app_name}-green-tg" }
}

# ═══════════════════════════════════════════════════════════════════
# ALB Listener — Production (port 80) → Blue Target Group
# ═══════════════════════════════════════════════════════════════════
resource "aws_lb_listener" "prod" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

# ═══════════════════════════════════════════════════════════════════
# ALB Listener — Stage (port 8080) → Green Target Group
# Harness uses this to test new version before swapping
# ═══════════════════════════════════════════════════════════════════
resource "aws_lb_listener" "stage" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.green.arn
  }
}

# ═══════════════════════════════════════════════════════════════════
# ECS Cluster (Fargate — serverless, no EC2 to manage)
# ═══════════════════════════════════════════════════════════════════
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.app_name}-cluster" }
}

# ═══════════════════════════════════════════════════════════════════
# IAM Role — ECS Task Execution (pulls images from ECR, writes logs)
# ═══════════════════════════════════════════════════════════════════
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.app_name}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution.name
}

# ═══════════════════════════════════════════════════════════════════
# IAM Role — ECS Task (runtime permissions for the app)
# ═══════════════════════════════════════════════════════════════════
resource "aws_iam_role" "ecs_task" {
  name = "${var.app_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ═══════════════════════════════════════════════════════════════════
# CloudWatch Log Group (ECS task logs)
# ═══════════════════════════════════════════════════════════════════
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 7

  tags = { Name = "${var.app_name}-logs" }
}
