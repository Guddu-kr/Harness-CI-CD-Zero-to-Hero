# ═══════════════════════════════════════════════════════════════════
# Harness Delegate on ECS Fargate
# Runs as a separate ECS service in the same cluster
# Connects to Harness Platform and executes deployment tasks
#
# CHANGE THESE: Set delegate_account_id and delegate_token in variables
# Get from: Harness → Project Settings → Delegates → Tokens
# ═══════════════════════════════════════════════════════════════════

# Task Definition for Harness Delegate
resource "aws_ecs_task_definition" "delegate" {
  family                   = "${var.app_name}-delegate"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.delegate_task.arn

  container_definitions = jsonencode([
    {
      name      = "harness-delegate"
      image     = "harness/delegate:latest"
      essential = true
      environment = [
        { name = "ACCOUNT_ID", value = var.delegate_account_id },
        { name = "DELEGATE_TOKEN", value = var.delegate_token },
        { name = "MANAGER_HOST_AND_PORT", value = "https://app.harness.io/gratis" },
        { name = "DELEGATE_NAME", value = "${var.app_name}-ecs-delegate" },
        { name = "NEXT_GEN", value = "true" },
        { name = "DELEGATE_TYPE", value = "DOCKER" },
        { name = "DELEGATE_TAGS", value = "ecs-fargate" },
        { name = "LOG_STREAMING_SERVICE_URL", value = "https://app.harness.io/gratis/log-service/" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "delegate"
        }
      }
    }
  ])
}

# ECS Service for Delegate (always running)
resource "aws_ecs_service" "delegate" {
  name            = "${var.app_name}-delegate"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.delegate.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  tags = { Name = "${var.app_name}-delegate" }
}

# IAM Role for Delegate Task (needs ECS + ECR + CloudWatch permissions)
resource "aws_iam_role" "delegate_task" {
  name = "${var.app_name}-delegate-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Delegate needs broad permissions to deploy ECS services
resource "aws_iam_role_policy_attachment" "delegate_ecs_full" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
  role       = aws_iam_role.delegate_task.name
}

resource "aws_iam_role_policy_attachment" "delegate_ecr_read" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.delegate_task.name
}

resource "aws_iam_role_policy_attachment" "delegate_elb_full" {
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  role       = aws_iam_role.delegate_task.name
}
