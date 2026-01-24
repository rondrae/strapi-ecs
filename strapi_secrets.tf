# Random secrets for Strapi auth tokens and app keys.
resource "random_password" "strapi_jwt_secret" {
  length  = 32
  special = false
}

resource "random_password" "strapi_admin_jwt_secret" {
  length  = 32
  special = false
}

resource "random_password" "strapi_api_token_salt" {
  length  = 32
  special = false
}

resource "random_password" "strapi_transfer_token_salt" {
  length  = 32
  special = false
}

resource "random_password" "strapi_app_key_1" {
  length  = 32
  special = false
}

resource "random_password" "strapi_app_key_2" {
  length  = 32
  special = false
}

resource "random_password" "strapi_app_key_3" {
  length  = 32
  special = false
}

resource "random_password" "strapi_app_key_4" {
  length  = 32
  special = false
}

# Store Strapi app secrets in Secrets Manager.
resource "aws_secretsmanager_secret" "strapi" {
  name = "${var.environment}/strapi/app-v2"
  tags = var.tags
}

# Persist Strapi secrets as a JSON payload.
resource "aws_secretsmanager_secret_version" "strapi" {
  secret_id = aws_secretsmanager_secret.strapi.id

  secret_string = jsonencode({
    app_keys            = join(",", [
      random_password.strapi_app_key_1.result,
      random_password.strapi_app_key_2.result,
      random_password.strapi_app_key_3.result,
      random_password.strapi_app_key_4.result
    ])
    jwt_secret          = random_password.strapi_jwt_secret.result
    admin_jwt_secret    = random_password.strapi_admin_jwt_secret.result
    api_token_salt      = random_password.strapi_api_token_salt.result
    transfer_token_salt = random_password.strapi_transfer_token_salt.result
  })
}
