locals {
  name_prefix = "${var.project_name}"
}

resource "random_id" "suffix" {
  byte_length = 2
}

# ---------------- VPC ----------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  for_each                = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, each.key)
  tags = {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "public"
  }
  depends_on = [data.aws_availability_zones.available]
}

resource "aws_subnet" "private" {
  for_each          = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = element(data.aws_availability_zones.available.names, each.key)
  tags = {
    Name = "${local.name_prefix}-private-${each.key}"
    Tier = "private"
  }
  depends_on = [data.aws_availability_zones.available]
}

resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"
}

resource "aws_nat_gateway" "nat" {
  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id
  tags = {
    Name = "${local.name_prefix}-nat-${each.key}"
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }
  tags = { Name = "${local.name_prefix}-private-rt-${each.key}" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ---------------- ECR ----------------
resource "aws_ecr_repository" "frontend" {
  name = "${local.name_prefix}-fe-${random_id.suffix.hex}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "backend" {
  name = "${local.name_prefix}-be-${random_id.suffix.hex}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# ---------------- IAM ----------------
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.name_prefix}-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "codebuild" {
  name = "${local.name_prefix}-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_inline" {
  name = "${local.name_prefix}-codebuild-inline"
  role = aws_iam_role.codebuild.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.name_prefix}*:*"
      },
      {
        Effect   = "Allow",
        Action   = ["ecr:GetAuthorizationToken"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage"
        ],
        Resource = [aws_ecr_repository.frontend.arn, aws_ecr_repository.backend.arn]
      },
      {
        Effect = "Allow",
        Action = ["s3:PutObject", "s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"],
        Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role" "codepipeline" {
  name = "${local.name_prefix}-codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_inline" {
  name = "${local.name_prefix}-codepipeline-inline"
  role = aws_iam_role.codepipeline.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
        Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
      },
      {
        Effect   = "Allow",
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"],
        Resource = [aws_codebuild_project.build.arn, aws_codebuild_project.build_frontend.arn]
      },
      {
        Effect   = "Allow",
        Action   = ["iam:PassRole"],
        Resource = [aws_iam_role.codebuild.arn, aws_iam_role.ecs_task_execution.arn]
      },
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ],
        Resource = [
          aws_ecs_service.frontend.arn,
          aws_ecs_service.backend.arn,
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${local.name_prefix}-fe-task:*",
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${local.name_prefix}-be-task:*"
        ]
      }
    ]
  })
}

# ---------------- S3/KMS ----------------
resource "aws_kms_key" "artifacts" {
  description             = "KMS key for CodePipeline artifacts"
  deletion_window_in_days = 7
}

resource "aws_kms_key_policy" "artifacts" {
  key_id = aws_kms_key.artifacts.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Effect = "Allow",
        Principal = { AWS = [aws_iam_role.codepipeline.arn, aws_iam_role.codebuild.arn] },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.artifacts.arn
      }
    ]
  })
}

resource "aws_kms_alias" "artifacts" {
  name          = "alias/${local.name_prefix}-artifacts"
  target_key_id = aws_kms_key.artifacts.key_id
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.name_prefix}-artifacts-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.artifacts.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_policy" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = [aws_iam_role.codepipeline.arn, aws_iam_role.codebuild.arn] }
        Action    = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource  = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
      }
    ]
  })
}

# ---------------- ECS + ALB ----------------
resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "app" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for s in aws_subnet.public : s.id]
}

resource "aws_lb_target_group" "frontend" {
  name        = "${local.name_prefix}-fe-tg"
  port        = var.frontend_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id
  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_security_group" "frontend_tasks" {
  name        = "${local.name_prefix}-fe-tasks-sg"
  description = "Frontend ECS tasks security group"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = var.frontend_container_port
    to_port         = var.frontend_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${local.name_prefix}-fe-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([
    {
      name  = "frontend"
      image = aws_ecr_repository.frontend.repository_url
      essential = true
      portMappings = [
        {
          containerPort = var.frontend_container_port
          hostPort      = var.frontend_container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.name_prefix}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
  depends_on = [aws_cloudwatch_log_group.ecs]
}

resource "aws_ecs_service" "frontend" {
  name            = "${local.name_prefix}-fe-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [for s in aws_subnet.private : s.id]
    security_groups  = [aws_security_group.frontend_tasks.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = var.frontend_container_port
  }
  depends_on = [aws_lb_listener.http]
}

resource "aws_security_group" "backend_tasks" {
  name        = "${local.name_prefix}-be-tasks-sg"
  description = "Backend ECS tasks security group"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = var.backend_container_port
    to_port         = var.backend_container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_tasks.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.name_prefix}-be-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([
    {
      name  = "backend"
      image = aws_ecr_repository.backend.repository_url
      essential = true
      portMappings = [
        {
          containerPort = var.backend_container_port
          hostPort      = var.backend_container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.name_prefix}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
  depends_on = [aws_cloudwatch_log_group.ecs]
}

resource "aws_ecs_service" "backend" {
  name            = "${local.name_prefix}-be-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.backend_desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [for s in aws_subnet.private : s.id]
    security_groups  = [aws_security_group.backend_tasks.id]
    assign_public_ip = false
  }
}

# ---------------- CodeBuild ----------------
resource "aws_codebuild_project" "build" {
  name          = "${local.name_prefix}-be-build"
  service_role  = aws_iam_role.codebuild.arn
  artifacts { type = "CODEPIPELINE" }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable = [
      { name = "ECR_REPO", value = aws_ecr_repository.backend.repository_url },
      { name = "AWS_DEFAULT_REGION", value = var.aws_region }
    ]
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2
phases:
  build:
    commands:
      - echo Build started
      - docker build -t $ECR_REPO:latest .
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REPO
      - docker push $ECR_REPO:latest
      - printf '[{"name":"backend","imageUri":"%s"}]' $ECR_REPO:latest > imagedefinitions.json
artifacts:
  files:
    - imagedefinitions.json
  discard-paths: yes
EOF
  }
}

resource "aws_codebuild_project" "build_frontend" {
  name          = "${local.name_prefix}-fe-build"
  service_role  = aws_iam_role.codebuild.arn
  artifacts { type = "CODEPIPELINE" }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable = [
      { name = "ECR_REPO", value = aws_ecr_repository.frontend.repository_url },
      { name = "AWS_DEFAULT_REGION", value = var.aws_region }
    ]
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2
phases:
  build:
    commands:
      - echo Build started
      - docker build -t $ECR_REPO:latest .
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REPO
      - docker push $ECR_REPO:latest
      - printf '[{"name":"frontend","imageUri":"%s"}]' $ECR_REPO:latest > imagedefinitions.json
artifacts:
  files:
    - imagedefinitions.json
  discard-paths: yes
EOF
  }
}

# ---------------- CodePipeline ----------------
resource "aws_codepipeline" "pipeline" {
  name     = "${local.name_prefix}-be-pipeline"
  role_arn = aws_iam_role.codepipeline.arn
  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
    encryption_key {
      id   = aws_kms_key.artifacts.arn
      type = "KMS"
    }
  }
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["be_source_output"]
      configuration = {
        ConnectionArn        = var.github_connection_arn
        FullRepositoryId     = "${var.github_owner}/${var.github_repo}"
        BranchName           = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["be_source_output"]
      output_artifacts = ["be_build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["be_build_output"]
      version         = "1"
      configuration = {
        ClusterName = aws_ecs_cluster.this.name
        ServiceName = aws_ecs_service.backend.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

resource "aws_codepipeline" "pipeline_frontend" {
  name     = "${local.name_prefix}-fe-pipeline"
  role_arn = aws_iam_role.codepipeline.arn
  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
    encryption_key {
      id   = aws_kms_key.artifacts.arn
      type = "KMS"
    }
  }
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["fe_source_output"]
      configuration = {
        ConnectionArn        = var.github_connection_arn
        FullRepositoryId     = "${var.github_owner}/${var.github_repo}"
        BranchName           = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["fe_source_output"]
      output_artifacts = ["fe_build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.build_frontend.name
      }
    }
  }
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["fe_build_output"]
      version         = "1"
      configuration = {
        ClusterName = aws_ecs_cluster.this.name
        ServiceName = aws_ecs_service.frontend.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

# ---------------- Outputs ----------------
output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "frontend_ecr_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "backend_ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}