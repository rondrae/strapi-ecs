# ALB in public subnets with HTTP listener to ECS targets.
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "10.5.0"

  name    = "${var.environment}-strapi-alb"
  vpc_id  = var.vpc_id
  subnets = var.public_subnet_ids

  security_group_ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP from the internet"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "strapi"
      }
    }
  }

  target_groups = {
    strapi = {
      name_prefix = "strp"
      protocol    = "HTTP"
      port        = var.ecs_container_port
      target_type = "ip"
      create_attachment = false
      health_check = {
        path    = "/admin"
        matcher = "200-399"
      }
    }
  }

  tags = var.tags
}
