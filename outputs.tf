output "alb_dns_name" {
  value = module.alb.dns_name
}

output "s3_bucket_name" {
  value = module.s3_bucket.s3_bucket_id
}

output "rds_cluster_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

output "rds_proxy_endpoint" {
  value = try(aws_db_proxy.this[0].endpoint, null)
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "strapi_secret_arn" {
  value = aws_secretsmanager_secret.strapi.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.strapi.repository_url
}
