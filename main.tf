terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">3"
    }
  }
}

locals {
  deployment_name = var.deployment_name == "" ? "nginx-test" : var.deployment_name
}

data aws_caller_identity current {}

data aws_ecr_repository ecr_repo {
  name = local.deployment_name
  count = var.container_image_name == "" ? 1 : 0
}

data aws_vpc vpc {
  default = true
  count = var.vpc_id == "" ? 1 : 0
}

data aws_availability_zones azs {
  state = "available"
}

data aws_subnet subnet {
  count = var.vpc_id == "" ? length(data.aws_availability_zones.azs.names) : 0
  vpc_id = data.aws_vpc.vpc[0].id
  availability_zone = data.aws_availability_zones.azs.names[count.index]
}

locals {
  vpc_id                      = var.vpc_id == "" ? data.aws_vpc.vpc[0].id : var.vpc_id
  deployment_group_listeners  = var.lb_certificate_arn == "" ? [ aws_lb_listener.elb_listener.arn ] : [ aws_lb_listener.elb_listener_https[0].arn ]
  container_image_name        = var.container_image_name == "" ? data.aws_ecr_repository.ecr_repo[0].repository_url : var.container_image_name
  security_group_ids          = length(var.security_group_ids) == 0 ? [aws_security_group.security_group_web.id] : var.security_group_ids
}

resource aws_security_group security_group_web {
  name = var.deployment_name
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 443
    to_port = 443
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

resource aws_lb elb {
  name = local.deployment_name
  load_balancer_type = "application"
  subnets = var.subnet_ids
  enable_cross_zone_load_balancing = true
  security_groups = [aws_security_group.security_group_web.id]

  tags = var.tags

}

resource aws_lb_target_group target_group_blue {
  name = "${local.deployment_name}-blue"
  target_type = "ip"
  health_check {
    enabled = true
    healthy_threshold = 2
    interval = var.health_check_interval
    path = var.health_check_path
    timeout = var.health_check_timeout
  }
  protocol = "HTTP"
  port = 80
  vpc_id = var.vpc_id

  tags = var.tags
}

resource aws_lb_target_group target_group_green {
  name = "${local.deployment_name}-green"
  target_type = "ip"
  health_check {
    enabled = true
    healthy_threshold = 2
    interval = var.health_check_interval
    path = var.health_check_path
    timeout = var.health_check_timeout
  }
  protocol = "HTTP"
  port = 80
  vpc_id = var.vpc_id

  tags = var.tags
}

resource aws_lb_listener elb_listener {
  load_balancer_arn = aws_lb.elb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.target_group_blue.arn
  }

  lifecycle {
    ignore_changes = [
      default_action[0].target_group_arn
    ]
  }
}

resource aws_lb_listener elb_listener_https {
  count = var.lb_certificate_arn == "" ? 0 : 1
  load_balancer_arn = aws_lb.elb.arn
  port = 443
  protocol = "HTTPS"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.target_group_blue.arn
  }
  certificate_arn = var.lb_certificate_arn
  ssl_policy = var.ssl_policy == "" ? "ELBSecurityPolicy-TLS-1-2-2017-01" : var.ssl_policy

  lifecycle {
    ignore_changes = [
      default_action[0].target_group_arn
    ]
  }
}

resource aws_codedeploy_app app {
  name = local.deployment_name
  compute_platform = "ECS"
}

resource aws_codedeploy_deployment_config deploy_config {
  compute_platform = "ECS"
  deployment_config_name = local.deployment_name
  traffic_routing_config {
    type = "TimeBasedLinear"
    time_based_linear {
      interval = 1
      percentage = 50
    }
  }
}

resource aws_iam_role codedeploy_role {
  name = "${local.deployment_name}-CodeDeployRole"
  assume_role_policy = <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
      {
      "Action": "sts:AssumeRole",
      "Principal": {
          "Service": ["codedeploy.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
      }
  ]
}
JSON
}

resource aws_iam_role_policy_attachment codedeploy_role_policy_attachment {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
  role = aws_iam_role.codedeploy_role.name
}

resource aws_s3_bucket codedeploy_s3 {
  bucket = "${local.deployment_name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = var.tags
}

resource aws_codedeploy_deployment_group deploy_group {
  app_name = aws_codedeploy_app.app.name
  deployment_group_name = local.deployment_name
  deployment_config_name = aws_codedeploy_deployment_config.deploy_config.deployment_config_name
  ecs_service {
    cluster_name = aws_ecs_cluster.ecs_cluster.name
    service_name = aws_ecs_service.ecs_service.name
  }
  autoscaling_groups = []
  service_role_arn = aws_iam_role.codedeploy_role.arn
  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = local.deployment_group_listeners
      }

      target_group {
        name = aws_lb_target_group.target_group_blue.name
      }

      target_group {
        name = aws_lb_target_group.target_group_green.name
      }
    }
  }
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action = "TERMINATE"
      termination_wait_time_in_minutes = var.termination_wait_time
    }
  }
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type = "BLUE_GREEN"
  }
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

resource aws_iam_role_policy_attachment ecs_task_execution_policy_attachments {
  count = length(var.task_exec_role_policies)
  policy_arn = var.task_exec_role_policies[count.index]
  role = aws_iam_role.ecs_task_execution_role.name
}

resource aws_iam_role ecs_task_role {
  name = "${var.deployment_name}-TaskRole"
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

resource aws_iam_role_policy_attachment ecs_task_policy_attachments {
  count = length(var.task_role_policies)
  policy_arn = var.task_role_policies[count.index]
  role = aws_iam_role.ecs_task_role.name
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
  task_role_arn = aws_iam_role.ecs_task_role.arn
  
}

resource local_file task_def_file {
  content = templatefile("${path.module}/appspec.yml", {task_arn = aws_ecs_task_definition.ecs_task.arn, deployment_name = local.deployment_name})
  filename = "${path.module}/build/appspec.yml"
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
      network_configuration,
      desired_count
    ]
  }
}