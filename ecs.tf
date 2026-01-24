# CloudWatch log group for ECS task logs.
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.environment}-strapi"
  retention_in_days = 14
  tags              = var.tags
}

# ECS cluster for Strapi tasks.
resource "aws_ecs_cluster" "this" {
  name = "${var.environment}-strapi"
  tags = var.tags
}

# Derived Strapi settings and DB target.
locals {
  strapi_public_url = coalesce(var.strapi_public_url, "http://${module.alb.dns_name}")
  strapi_admin_url  = coalesce(var.strapi_admin_url, "${local.strapi_public_url}/admin")
  strapi_cors       = coalesce(var.strapi_cors_origin, "*")
  strapi_img_origin = coalesce(var.strapi_img_origin, "self,data:,blob:,market-assets.strapi.io")
  strapi_db_host    = var.enable_rds_proxy ? aws_db_proxy.this[0].endpoint : aws_rds_cluster.aurora.endpoint
}

# Security group allowing ALB to reach ECS tasks.
resource "aws_security_group" "ecs_service" {
  name        = "${var.environment}-ecs-service"
  description = "ECS service access from ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "ALB to ECS"
    from_port       = var.ecs_container_port
    to_port         = var.ecs_container_port
    protocol        = "tcp"
    security_groups = [module.alb.security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Task definition for the Strapi container.
resource "aws_ecs_task_definition" "strapi" {
  family                   = "${var.environment}-strapi"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  # Strapi runtime env vars and secrets are injected here.
  container_definitions = jsonencode([
    {
      name  = "strapi"
      image = var.ecs_container_image

      portMappings = [
        {
          containerPort = var.ecs_container_port
          hostPort      = var.ecs_container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }

      environment = [
        { name = "NODE_ENV", value = var.strapi_node_env },
        { name = "CI", value = "true" },
        { name = "STRAPI_TELEMETRY_DISABLED", value = "true" },
        { name = "HOST", value = "0.0.0.0" },
        { name = "PORT", value = tostring(var.ecs_container_port) },
        { name = "PUBLIC_URL", value = local.strapi_public_url },
        { name = "ADMIN_URL", value = local.strapi_admin_url },
        { name = "BUILD", value = tostring(var.strapi_build) },
        { name = "CORS_ORIGIN", value = local.strapi_cors },
        { name = "IMG_ORIGIN", value = local.strapi_img_origin },
        { name = "DATABASE_CLIENT", value = "postgres" },
        { name = "DATABASE_HOST", value = local.strapi_db_host },
        { name = "DATABASE_PORT", value = tostring(var.db_port) },
        { name = "DATABASE_NAME", value = var.db_name },
        { name = "DATABASE_USERNAME", value = var.db_username },
        { name = "DATABASE_SSL", value = "true" },
        { name = "DATABASE_SSL_REJECT_UNAUTHORIZED", value = "false" },
        { name = "PGSSLMODE", value = "require" }
      ]

      secrets = [
        { name = "DATABASE_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db.arn}:password::" },
        { name = "JWT_SECRET", valueFrom = "${aws_secretsmanager_secret.strapi.arn}:jwt_secret::" },
        { name = "ADMIN_JWT_SECRET", valueFrom = "${aws_secretsmanager_secret.strapi.arn}:admin_jwt_secret::" },
        { name = "APP_KEYS", valueFrom = "${aws_secretsmanager_secret.strapi.arn}:app_keys::" },
        { name = "API_TOKEN_SALT", valueFrom = "${aws_secretsmanager_secret.strapi.arn}:api_token_salt::" },
        { name = "TRANSFER_TOKEN_SALT", valueFrom = "${aws_secretsmanager_secret.strapi.arn}:transfer_token_salt::" }
      ]
    }
  ])
}

# ECS service keeps the desired task count running behind the ALB.
resource "aws_ecs_service" "strapi" {
  name            = "${var.environment}-strapi"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.strapi.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"
  health_check_grace_period_seconds = 300

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = module.alb.target_groups["strapi"].arn
    container_name   = "strapi"
    container_port   = var.ecs_container_port
  }

  depends_on = [module.alb]
}
