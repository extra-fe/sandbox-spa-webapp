resource "aws_security_group" "alb" {
  name = "${var.app-name}-${var.environment}-internal-alb"
  tags = {
    "Name" = "internal-alb"
  }
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "alb_out" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "ecs_service" {
  name = "${var.app-name}-${var.environment}-ecs-service"
  tags = {
    "Name" = "ecs-service"
  }
  vpc_id = aws_vpc.vpc.id
  timeouts {}
}

resource "aws_security_group_rule" "ecs_service_in_alb" {
  security_group_id        = aws_security_group.ecs_service.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = var.api-expose-port
  to_port                  = var.api-expose-port
  source_security_group_id = aws_security_group.alb.id
  description              = "internal ALB target group"
}

resource "aws_security_group_rule" "ecs_service_out" {
  security_group_id = aws_security_group.ecs_service.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

data "aws_security_group" "cloudfront_vpc_origin" {
  filter {
    name   = "group-name"
    values = ["CloudFront-VPCOrigins-Service-SG"]
  }
  filter {
    name   = "vpc-id"
    values = [aws_vpc.vpc.id]
  }
  depends_on = [aws_cloudfront_vpc_origin.alb]
}

resource "aws_security_group_rule" "alb_in" {
  security_group_id        = aws_security_group.alb.id
  type                     = "ingress"
  protocol                 = "-1"
  from_port                = 80
  to_port                  = 80
  source_security_group_id = data.aws_security_group.cloudfront_vpc_origin.id
  description              = "CloudFront VPC Origin http"
}
