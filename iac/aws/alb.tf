resource "aws_lb_target_group" "to_ecs_service" {
  deregistration_delay          = "300"
  load_balancing_algorithm_type = "round_robin"
  name                          = "${var.app-name}-${var.environment}-ecs"
  port                          = var.api-expose-port
  protocol                      = "HTTP"
  protocol_version              = "HTTP1"
  slow_start                    = 0
  tags                          = {}
  target_type                   = "ip"
  vpc_id                        = aws_vpc.vpc.id
  health_check {
    enabled             = true
    healthy_threshold   = 5
    interval            = 30
    matcher             = "200"
    path                = var.health-check-path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  stickiness {
    cookie_duration = 86400
    enabled         = false
    type            = "lb_cookie"
  }
}

resource "aws_lb" "alb" {
  drop_invalid_header_fields = false
  enable_deletion_protection = false
  enable_http2               = true
  idle_timeout               = 60
  internal                   = true
  ip_address_type            = "ipv4"
  load_balancer_type         = "application"
  name                       = "${var.app-name}-${var.environment}-alb"
  security_groups = [
    aws_security_group.alb.id,
  ]
  subnets = [
    aws_subnet.private1a.id,
    aws_subnet.private1c.id,
  ]
  tags = {}
  access_logs {
    enabled = false
    bucket  = ""
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  tags              = {}
  default_action {
    order = 1
    type  = "fixed-response"
    fixed_response {
      status_code  = 404
      message_body = ""
      content_type = "text/plain"
    }
  }
}

resource "aws_lb_listener_rule" "from_cloudfront" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1
  tags         = {}
  action {
    order            = 10
    target_group_arn = aws_lb_target_group.to_ecs_service.arn
    type             = "forward"
  }
  condition {
    path_pattern {
      values = [
        var.api-base-path,
      ]
    }
  }
}
