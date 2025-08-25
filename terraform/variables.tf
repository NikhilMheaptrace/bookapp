variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "my-app"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "frontend_container_port" {
  description = "Port for the frontend container"
  type        = number
  default     = 80
}

variable "backend_container_port" {
  description = "Port for the backend container"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "CPU units for ECS tasks"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Memory for ECS tasks"
  type        = string
  default     = "512"
}

variable "frontend_desired_count" {
  description = "Desired number of frontend tasks"
  type        = number
  default     = 2
}

variable "backend_desired_count" {
  description = "Desired number of backend tasks"
  type        = number
  default     = 2
}

variable "github_connection_arn" {
  description = "ARN of the CodeStar connection to GitHub"
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to monitor"
  type        = string
  default     = "main"
}