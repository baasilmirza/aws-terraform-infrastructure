variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (tagging + resource names)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name used in resource naming"
  type        = string
  default     = "project02"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.0.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_ami" {
  description = "AMI id override; defaults to latest Amazon Linux 2023"
  type        = string
  default     = null
}

variable "ssm_session_allowed" {
  description = "Toggle to intentionally DENY SSM sessions on the ops role (IAM least-privilege demo). True = allowed, false = denied."
  type        = bool
  default     = true
}
