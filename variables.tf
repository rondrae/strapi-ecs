variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "s3_bucket_prefix" {
  type = string
}

variable "ecr_repo_name" {
  type = string
}

variable "ecs_container_image" {
  type    = string
  default = "vshadbolt/strapi:latest"
}

variable "ecs_container_port" {
  type    = number
  default = 1337
  #default = 80
}

variable "ecs_desired_count" {
  type    = number
  default = 1
}

variable "ecs_task_cpu" {
  type    = number
  default = 256
}

variable "ecs_task_memory" {
  type    = number
  default = 512
}

variable "db_name" {
  type    = string
  default = "strapi"
}

variable "db_username" {
  type    = string
  default = "strapi_admin"
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_engine_version" {
  type    = string
  default = "17.4"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "enable_rds_proxy" {
  type    = bool
  default = false
}

variable "strapi_public_url" {
  type    = string
  default = null
}

variable "strapi_admin_url" {
  type    = string
  default = null
}

variable "strapi_cors_origin" {
  type    = string
  default = null
}

variable "strapi_img_origin" {
  type    = string
  default = null
}

variable "strapi_build" {
  type    = bool
  default = true
}

variable "strapi_node_env" {
  type    = string
  default = "production"
}

variable "tags" {
  type    = map(string)
  default = {}
}
