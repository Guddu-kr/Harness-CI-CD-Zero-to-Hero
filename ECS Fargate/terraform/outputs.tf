output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "blue_target_group_arn" {
  value = aws_lb_target_group.blue.arn
}

output "green_target_group_arn" {
  value = aws_lb_target_group.green.arn
}

output "prod_listener_arn" {
  value = aws_lb_listener.prod.arn
}

output "stage_listener_arn" {
  value = aws_lb_listener.stage.arn
}

output "task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.ecs_task.arn
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs_tasks.id
}

output "subnet_ids" {
  value = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "region" {
  value = var.aws_region
}

output "app_url" {
  value = "http://${aws_lb.main.dns_name}"
}
