data aws_caller_identity current {}

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

locals {
  deployment_group_listeners = var.lb_certificate_arn == "" ? [ aws_lb_listener.elb_listener.arn ] : [ aws_lb_listener.elb_listener_https[0].arn ]
}

resource aws_codedeploy_deployment_group deploy_group {
  app_name = aws_codedeploy_app.app.name
  deployment_group_name = local.deployment_name
  deployment_config_name = aws_codedeploy_deployment_config.deploy_config.deployment_config_name
  ecs_service {
    cluster_name = aws_ecs_cluster.ecs_cluster.name
    service_name = aws_ecs_service.ecs_service.name
  }
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
      termination_wait_time_in_minutes = 5
    }
  }
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type = "BLUE_GREEN"
  }
}

output s3_bucket_name {
  value = aws_s3_bucket.codedeploy_s3.bucket
}