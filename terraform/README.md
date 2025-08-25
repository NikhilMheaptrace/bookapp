Terraform for VPC, ECS Fargate, ECR, CodeBuild/CodePipeline

Usage
1) Create terraform/terraform.tfvars with required values:
project_name = "bolt-app"
aws_region = "us-east-1"
github_connection_arn = "arn:aws:codestar-connections:..."
github_owner = "YOUR_GH_OWNER"
github_repo = "YOUR_REPO_NAME"
github_branch = "main"
container_port = 3000
2) Run: terraform init && terraform apply
3) Open output alb_dns_name in a browser

Details
- Creates VPC (2 public, 2 private), IGW, NAT
- ECR repo, ECS Fargate service behind ALB
- S3 + KMS for artifacts
- CodeBuild + CodePipeline (GitHub → build → ECS deploy)

