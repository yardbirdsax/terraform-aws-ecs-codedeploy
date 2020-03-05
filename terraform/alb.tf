resource aws_lb elb {
  name = local.deployment_name
  load_balancer_type = "application"
  subnets = var.subnet_ids
  enable_cross_zone_load_balancing = true
  security_groups = [aws_security_group.security_group_web.id]
}

resource aws_lb_target_group target_group_blue {
  name = "${local.deployment_name}-blue"
  target_type = "ip"
  health_check {
    enabled = true
    healthy_threshold = 2
    interval = 10
    path = "/"
  }
  protocol = "HTTP"
  port = 80
  vpc_id = var.vpc_id
}

resource aws_lb_target_group target_group_green {
  name = "${local.deployment_name}-green"
  target_type = "ip"
  health_check {
    enabled = true
    healthy_threshold = 2
    interval = 10
    path = "/"
  }
  protocol = "HTTP"
  port = 80
  vpc_id = var.vpc_id
}

resource aws_lb_listener elb_listener {
  load_balancer_arn = aws_lb.elb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.target_group_blue.arn
  }
}

output alb_url {
  value = "http://${aws_lb.elb.dns_name}"
}