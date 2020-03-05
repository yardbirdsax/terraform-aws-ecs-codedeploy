provider aws {
  region = "us-east-2"
}

data aws_ecr_repository ecr_repo {
  name = local.deployment_name
  count = var.container_image_name == "" ? 1 : 0
}

locals {
  container_image_name = var.container_image_name == "" ? data.aws_ecr_repository.ecr_repo[0].repository_url : var.container_image_name
}

resource aws_ecs_cluster ecs_cluster {
  name = "codedeploy-ecs-test"
}

resource aws_iam_role ecs_task_role {
  name = "nginx-testRole"
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

resource aws_iam_role_policy ecs_task_policy {
  name = "nginx-testPolicy"
  role = aws_iam_role.ecs_task_role.name
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

resource aws_ecs_task_definition ecs_task {
  cpu = 256
  memory = 512

  container_definitions = <<JSON
[
  {
      "cpu": 256,
      "environment": [],            
      "essential": true,
      "image": "${local.container_image_name}:${var.container_image_tag}",
      "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
              "awslogs-group": "/ecs/nginx-test",
              "awslogs-region": "us-east-2",
              "awslogs-stream-prefix": "ecs",
              "awslogs-create-group": "true"
          }
      },
      "memory": 64,
      "mountPoints": [],
      "name": "${local.deployment_name}",
      "portMappings": [{
          "containerPort": 80,
          "hostPort": 80,
          "protocol": "tcp"
      }],
      "secrets": [],
      "volumesFrom": []
  }
]
JSON

  family = local.deployment_name
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  execution_role_arn = aws_iam_role.ecs_task_role.arn
  
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
    security_groups = [aws_security_group.security_group_web.id]
  }
  desired_count = 2

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