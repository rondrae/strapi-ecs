# VPC metadata for endpoint routing and CIDR.
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Find route tables associated with private subnets.
data "aws_route_table" "private" {
  for_each = toset(var.private_subnet_ids)

  filter {
    name   = "association.subnet-id"
    values = [each.value]
  }
}

# Deduplicate route tables for the S3 gateway endpoint.
locals {
  private_route_table_ids = distinct([for rt in data.aws_route_table.private : rt.id])
}

# Security group for interface endpoints (HTTPS from VPC).
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.environment}-vpc-endpoints"
  description = "Interface VPC endpoints access"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Interface endpoint for Secrets Manager.
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = var.tags
}

# Interface endpoint for CloudWatch Logs.
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = var.tags
}

# Interface endpoint for ECR API.
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = var.tags
}

# Interface endpoint for ECR Docker registry.
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  tags = var.tags
}

# Gateway endpoint for S3 (ECR layers, uploads).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.private_route_table_ids

  tags = var.tags
}
