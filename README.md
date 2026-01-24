# Strapi ECS Infrastructure (Up to Nginx Working)

This README summarizes the steps and Terraform changes completed to get the infrastructure running and the ALB serving the Nginx container (before switching to Strapi).

## What was built

- ECS Fargate cluster + service in private subnets (multi-AZ)
- Application Load Balancer (ALB) in public subnets
- Aurora PostgreSQL cluster (2 instances, multi-AZ)
- S3 bucket (private, encrypted, versioned)
- CloudWatch log group for ECS logs
- IAM roles for ECS task execution and task runtime
- Optional RDS Proxy (disabled by default)
- ECR repo (created later, not required for the Nginx step)

## Files created/updated

- `main.tf`: AWS + random providers, default tags
- `alb.tf`: ALB module, listener, target group, security group rules
- `ecs.tf`: ECS cluster/service/task definition, IAM roles, log group
- `aurora.tf`: Aurora cluster + instances, subnet group, DB SG, DB secret
- `s3.tf`: S3 module with private access + encryption + versioning
- `variables.tf`: inputs for region, VPC/subnets, ECS, DB, tags
- `dev.tfvars`: environment values (region, VPC, subnets, tags)
- `outputs.tf`: ALB DNS, S3, DB endpoints

## Inputs used (dev.tfvars)

- Region: `ca-central-1`
- VPC: `vpc-022c605c5658ffbde`
- Public subnets: `subnet-0fae6e6652c80191e`, `subnet-0163de1cc81ef122a`
- Private subnets: `subnet-02cfd416af5790eb2`, `subnet-0be88090c8c6f7eb9`

## Key steps to get Nginx working

1) **Terraform foundation**
   - Configured AWS provider with region and default tags.
   - Added variables + dev.tfvars for VPC/subnet IDs and tags.

2) **ALB**
   - Created ALB in public subnets.
   - Added HTTP listener on port 80.
   - Added target group for ECS tasks.
   - Disabled target-group attachments inside the ALB module so ECS can manage attachments.

3) **ECS Fargate**
   - Created ECS cluster + service.
   - Task definition initially used `public.ecr.aws/nginx/nginx:latest`.
   - Set container port to `80` to match Nginx.
   - Service runs in private subnets with `assign_public_ip = false`.

4) **S3 + Aurora**
   - S3 bucket module added (private, SSE-S3, versioning).
   - Aurora cluster + instances in private subnets (small size).

5) **Networking**
   - Added a NAT gateway so ECS tasks in private subnets can pull container images.
   - Ensured private subnet route tables send `0.0.0.0/0` to the NAT.

6) **Nginx verification**
   - Once NAT was available, ECS tasks could pull images.
   - ALB DNS showed the Nginx welcome page.

## Commands used

```bash
terraform init
terraform apply -var-file=dev.tfvars
```

## Notes

- The ALB showed `502/503` until the NAT gateway was in place and ECS tasks could pull the Nginx image.
- After setting the container port to `80`, ALB returned the Nginx welcome page.

