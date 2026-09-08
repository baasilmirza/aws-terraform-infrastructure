variable "vpc_id" {
  description = "VPC id to launch into"
  type        = string
}

variable "subnet_id" {
  description = "Private subnet id to launch the instance into"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "instance_ami" {
  description = "AMI id override; defaults to latest Amazon Linux 2023"
  type        = string
  default     = null
}

variable "instance_profile" {
  description = "IAM instance profile name to attach"
  type        = string
}

variable "environment" {
  description = "Environment suffix for resource names"
  type        = string
}

data "aws_ami" "amazon_linux_2023" {
  count       = var.instance_ami == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
