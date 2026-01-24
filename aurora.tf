# DB subnet group in private subnets.
resource "aws_db_subnet_group" "db" {
  name       = "${var.environment}-strapi-db"
  subnet_ids = var.private_subnet_ids

  tags = var.tags
}

# DB security group allowing ECS access.
resource "aws_security_group" "db" {
  name        = "${var.environment}-strapi-db"
  description = "Aurora access from ECS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "ECS to Aurora"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Random DB master password.
resource "random_password" "db" {
  length  = 24
  special = false
}

# Aurora PostgreSQL cluster.
resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "${var.environment}-strapi"
  engine                  = "aurora-postgresql"
  engine_version          = var.db_engine_version
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = random_password.db.result
  db_subnet_group_name    = aws_db_subnet_group.db.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  storage_encrypted       = true
  backup_retention_period = 7
  skip_final_snapshot     = var.db_skip_final_snapshot

  tags = var.tags
}

# Two Aurora instances across AZs.
resource "aws_rds_cluster_instance" "aurora" {
  count              = 2
  identifier         = "${var.environment}-strapi-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
  db_subnet_group_name = aws_db_subnet_group.db.name
  publicly_accessible = false

  tags = var.tags
}

# Store DB connection details for ECS.
resource "aws_secretsmanager_secret" "db" {
  name = "${var.environment}/strapi/db-v2"
  tags = var.tags
}

# Persist DB secret values.
resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    dbname   = var.db_name
    host     = aws_rds_cluster.aurora.endpoint
    port     = var.db_port
  })
}

# Optional RDS Proxy role.
resource "aws_iam_role" "rds_proxy" {
  count = var.enable_rds_proxy ? 1 : 0
  name  = "${var.environment}-rds-proxy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# RDS Proxy read access to DB secret.
resource "aws_iam_role_policy" "rds_proxy_secrets" {
  count = var.enable_rds_proxy ? 1 : 0
  name  = "${var.environment}-rds-proxy-secrets"
  role  = aws_iam_role.rds_proxy[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.db.arn]
      }
    ]
  })
}

# Optional RDS Proxy.
resource "aws_db_proxy" "this" {
  count = var.enable_rds_proxy ? 1 : 0

  name                   = "${var.environment}-strapi"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.rds_proxy[0].arn
  vpc_subnet_ids         = var.private_subnet_ids
  vpc_security_group_ids = [aws_security_group.db.id]
  require_tls            = true
  idle_client_timeout    = 1800

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.db.arn
  }

  tags = var.tags
}

# Default target group for RDS Proxy.
resource "aws_db_proxy_default_target_group" "this" {
  count         = var.enable_rds_proxy ? 1 : 0
  db_proxy_name = aws_db_proxy.this[0].name

  connection_pool_config {
    max_connections_percent = 90
  }
}

# Attach Aurora to the proxy target group.
resource "aws_db_proxy_target" "this" {
  count              = var.enable_rds_proxy ? 1 : 0
  db_proxy_name      = aws_db_proxy.this[0].name
  target_group_name  = aws_db_proxy_default_target_group.this[0].name
  db_cluster_identifier = aws_rds_cluster.aurora.id
}
