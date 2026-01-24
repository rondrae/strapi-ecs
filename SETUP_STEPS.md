# Terraform Build Order (From Scratch)

This file lists the recommended order to write the Terraform files and why each step exists.

## 1) Provider and core settings
**Files:** `main.tf`, `variables.tf`, `dev.tfvars`  
**Why:** You need the AWS provider and inputs (region, VPC/subnets, tags) before anything can be referenced.

- `main.tf`: required providers (aws, random) + provider config + default tags.
- `variables.tf`: define all inputs so modules/resources can reference them cleanly.
- `dev.tfvars`: environment values (region, VPC ID, subnet IDs, tags).

## 2) Networking context (existing VPC)
**Files:** `endpoints.tf`  
**Why:** Private subnets need access to AWS services (Secrets Manager, ECR, Logs, S3). Without endpoints or NAT, ECS tasks will fail to pull images or write logs.

- Data lookups for private subnet route tables.
- Interface endpoints: `secretsmanager`, `logs`, `ecr.api`, `ecr.dkr`.
- Gateway endpoint: `s3` (needed for ECR layers + S3 access).

## 3) ALB in public subnets
**Files:** `alb.tf`  
**Why:** Public entry point so users can reach the app; routes traffic to ECS tasks in private subnets.

- ALB module with public subnet IDs.
- Listener on port 80.
- Target group for ECS tasks (type `ip`).

## 4) ECS cluster + service (app runtime)
**Files:** `ecs.tf`  
**Why:** Runs the Strapi container, attaches to ALB, and configures runtime environment.

- ECS cluster.
- ECS task definition (image, ports, env vars, secrets).
- ECS service (Fargate, private subnets, ALB attachment).
- CloudWatch log group for container logs.
- SG allowing ALB -> ECS.

## 5) IAM roles and policies
**Files:** `iam.tf`  
**Why:** ECS needs permissions to pull images and read secrets; Strapi needs access to S3 + Secrets Manager.

- ECS execution role + Secrets Manager permissions.
- ECS task role + S3 + Secrets Manager permissions.

## 6) Database (Aurora)
**Files:** `aurora.tf`  
**Why:** Strapi stores application data in PostgreSQL; Aurora provides multi-AZ and managed backups.

- DB subnet group (private subnets).
- DB security group (allow ECS).
- Aurora cluster + 2 instances.
- Secrets Manager entry for DB credentials.
- Optional RDS Proxy (disabled by default).

## 7) Object storage (S3)
**Files:** `s3.tf`  
**Why:** Media/uploads should be external to ECS task storage.

- S3 bucket with encryption, versioning, and blocked public access.

## 8) Container registry
**Files:** `ecr.tf`  
**Why:** Store and deploy your custom Strapi image.

- ECR repo + lifecycle policy.

## 9) Strapi secrets
**Files:** `strapi_secrets.tf`  
**Why:** Strapi requires JWT/app secrets; store them in Secrets Manager and inject into ECS.

- Random secret generation.
- Secrets Manager entry for Strapi app secrets.

## 10) Outputs
**Files:** `outputs.tf`  
**Why:** Expose important endpoints (ALB DNS, DB endpoints, secret ARNs).

## Recommended build/apply order
1. `main.tf`, `variables.tf`, `dev.tfvars`
2. `endpoints.tf`
3. `alb.tf`
4. `iam.tf`
5. `ecs.tf`
6. `aurora.tf`
7. `s3.tf`
8. `ecr.tf`
9. `strapi_secrets.tf`
10. `outputs.tf`

Then run:
```
terraform init
terraform apply -var-file=dev.tfvars
```
