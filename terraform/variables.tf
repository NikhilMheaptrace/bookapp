variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "bookapp"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-south-1"
}

variable "github_connection_arn" {
  description = "ARN of the CodeStar connection to GitHub"
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner (username or organization)"
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

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "frontend_container_port" {
  description = "Port for the frontend container"
  type        = number
  default     = 80
}

variable "backend_container_port" {
  description = "Port for the backend container"
  type        = number
  default     = 5000
}

variable "frontend_desired_count" {
  description = "Desired number of frontend ECS tasks"
  type        = number
  default     = 1
}

variable "backend_desired_count" {
  description = "Desired number of backend ECS tasks"
  type        = number
  default     = 1
}

variable "ec2_instance_type" {
  description = "EC2 instance type for ECS"
  type        = string
  default     = "t2.micro"
}

variable "ec2_min_size" {
  description = "Minimum number of EC2 instances in the autoscaling group"
  type        = number
  default     = 1
}

variable "ec2_max_size" {
  description = "Maximum number of EC2 instances in the autoscaling group"
  type        = number
  default     = 2
}

variable "ec2_desired_capacity" {
  description = "Desired number of EC2 instances in the autoscaling group"
  type        = number
  default     = 1
}

variable "memory" {
  description = "Memory (in MiB) for ECS task containers"
  type        = number
  default     = 512
}

variable "cpu" {
  description = "CPU units for ECS task containers"
  type        = number
  default     = 256
}