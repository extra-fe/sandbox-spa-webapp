resource "aws_ecs_cluster" "cluster" {
  name = "${var.app-name}-${var.environment}-cluster"
  tags = {}
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.app-name}-${var.environment}-log"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "task_definition" {
  container_definitions = jsonencode(
    [
      {
        cpu         = 0
        environment = []
        essential   = true
        image       = "${aws_ecr_repository.backend.repository_url}:latest"
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.backend.name
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "ecs"
          }
        }
        mountPoints = []
        name        = "${var.app-name}"
        portMappings = [
          {
            containerPort = var.api-expose-port
            hostPort      = var.api-expose-port
            protocol      = "tcp"
          },
        ],
        environment = [
          {
            "name"  = "PORT",
            "value" = tostring(var.api-expose-port)
          },
          {
            "name"  = "LOG_LEVEL",
            "value" = "debug"
          },
          {
            "name"  = "AUTH0_DOMAIN",
            "value" = var.auth0_domain
          },

          {
            "name"  = "AUTH0_AUDIENCE",
            "value" = "https://${aws_cloudfront_distribution.cdn.domain_name}"
          },

          {
            "name"  = "CORS_ORIGIN",
            "value" = "https://${aws_cloudfront_distribution.cdn.domain_name}"
          },

          {
            "name"  = "CORS_METHODS",
            "value" = "GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS"
          },
        ]
        volumesFrom = []
      },
    ]
  )
  cpu                = "256"
  execution_role_arn = aws_iam_role.execute_ecs_task.arn
  family             = "${var.app-name}-${var.environment}-def"
  memory             = "512"
  network_mode       = "awsvpc"
  requires_compatibilities = [
    "FARGATE",
  ]
  tags          = {}
  task_role_arn = aws_iam_role.ecs_task.arn
}


resource "aws_iam_role" "ecs_task" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2012-10-17"
    }
  )
  description = null
  name        = "ecs-task-${var.app-name}-${var.environment}-role"
  path        = "/"
  tags        = {}
}

resource "aws_iam_role" "execute_ecs_task" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
          Sid = ""
        },
      ]
      Version = "2008-10-17"
    }
  )
  name = "ecs-task-execution-${var.app-name}-${var.environment}-role"
  path = "/"
  tags = {}
}


resource "aws_iam_role_policy" "execute_ecs_task" {
  name = "inline-2"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "ecr:GetRegistryPolicy",
            "ecr:DescribeRegistry",
            "ecr:GetAuthorizationToken",
            "ecr:DeleteRegistryPolicy",
            "ecr:PutRegistryPolicy",
            "ecr:PutReplicationConfiguration",
          ]
          Effect   = "Allow"
          Resource = aws_ecr_repository.backend.arn
        },
      ]
      Version = "2012-10-17"
    }
  )
  role = aws_iam_role.execute_ecs_task.name
}

resource "aws_iam_role_policy_attachment" "managed-ECSTaskExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.execute_ecs_task.name
}

resource "aws_ecs_service" "service" {
  cluster                            = aws_ecs_cluster.cluster.arn
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 1
  enable_ecs_managed_tags            = true
  enable_execute_command             = false
  health_check_grace_period_seconds  = 0
  launch_type                        = "FARGATE"
  name                               = "${var.app-name}-${var.environment}-service"
  platform_version                   = "LATEST"
  scheduling_strategy                = "REPLICA"
  tags                               = {}
  task_definition                    = "${aws_ecs_task_definition.task_definition.id}:${aws_ecs_task_definition.task_definition.revision}"
  wait_for_steady_state              = false
  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }
  deployment_controller {
    type = "ECS"
  }
  load_balancer {
    container_name   = var.app-name
    container_port   = var.api-expose-port
    target_group_arn = aws_lb_target_group.to_ecs_service.id
  }
  network_configuration {
    assign_public_ip = false
    security_groups = [
      aws_security_group.ecs_service.id,
    ]
    subnets = [
      aws_subnet.private1a.id,
      aws_subnet.private1c.id,
    ]
  }
  depends_on = [
    aws_ecs_task_definition.task_definition
  ]
  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }
}
