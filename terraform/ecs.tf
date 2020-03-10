provider aws {
  region = var.aws_region_name
}

data aws_ecr_repository ecr_repo {
  name = local.deployment_name
  count = var.container_image_name == "" ? 1 : 0
}

locals {
  container_image_name = var.container_image_name == "" ? data.aws_ecr_repository.ecr_repo[0].repository_url : var.container_image_name
}

resource aws_ecs_cluster ecs_cluster {
  name = var.deployment_name
}

resource aws_iam_role ecs_task_execution_role {
  name = "${var.deployment_name}-TaskExecutionRole"
  assume_role_policy = <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
      {
      "Action": "sts:AssumeRole",
      "Principal": {
          "Service": ["ecs-tasks.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
      }
  ]
}
JSON
}

resource aws_iam_role_policy ecs_task_execution_policy {
  name = "${var.deployment_name}-TaskExecutionPolicy"
  role = aws_iam_role.ecs_task_execution_role.name
  policy = <<JSON
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Effect":"Allow",
      "Action":[
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
JSON
}

resource aws_iam_policy_attachment ecs_task_policy_attachments {
  count = length(var.task_exec_role_policies)
  name = "${var.deployment_name}-policyattachment-${count.index}"
  policy_arn = var.task_exec_role_policies[count.index]
  roles = [ aws_iam_role.ecs_task_execution_role.name ]
}

resource aws_ecs_task_definition ecs_task {
  cpu = var.container_cpu
  memory = var.container_memory

  container_definitions = <<JSON
[
  {
      "cpu": ${var.container_cpu},
      "environment":${jsonencode(var.container_environment_variables)},            
      "essential": true,
      "image": "${local.container_image_name}:${var.container_image_tag}",
      "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
              "awslogs-group": "/ecs/${var.deployment_name}",
              "awslogs-region": "${var.aws_region_name}",
              "awslogs-stream-prefix": "ecs",
              "awslogs-create-group": "true"
          }
      },
      "memory": ${var.container_memory},
      "mountPoints": [],
      "name": "${local.deployment_name}",
      "portMappings": [{
          "containerPort": 80,
          "hostPort": 80,
          "protocol": "tcp"
      }],
      "secrets": ${jsonencode(var.container_secrets)},
      "volumesFrom": []
  }
]
JSON

  family = local.deployment_name
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  
}

resource local_file task_def_file {
  content = templatefile("${path.module}/appspec.yml", {task_arn = aws_ecs_task_definition.ecs_task.arn, deployment_name = local.deployment_name})
  filename = "${path.module}/build/appspec.yml"
}

resource aws_security_group security_group_web {
  name = var.deployment_name
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }

  vpc_id = local.vpc_id
  
}

locals {
  security_group_ids = length(var.security_group_ids) == 0 ? [aws_security_group.security_group_web.id] : var.security_group_ids
}

resource aws_ecs_service ecs_service {
  name = local.deployment_name
  cluster = aws_ecs_cluster.ecs_cluster.arn
  deployment_controller {
    type = "CODE_DEPLOY"
  }
  task_definition = aws_ecs_task_definition.ecs_task.arn
  launch_type = "FARGATE"
  load_balancer {
    container_name = local.deployment_name
    container_port = 80
    target_group_arn = aws_lb_target_group.target_group_blue.arn
  }
  network_configuration {
    subnets = var.subnet_ids
    assign_public_ip = true
    security_groups = local.security_group_ids
  }
  desired_count = var.desired_count

  depends_on = [
    aws_lb_listener.elb_listener
  ]

  lifecycle {
    ignore_changes = [
      load_balancer,
      task_definition,
      network_configuration
    ]
  }
}