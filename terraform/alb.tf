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

output alb_url {
  value = "http://${aws_lb.elb.dns_name}"
}

output alb {
  value = aws_lb.elb
}