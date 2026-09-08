variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ"
  type        = list(string)
}

variable "environment" {
  description = "Environment suffix for resource names"
  type        = string
}

variable "enable_dns_hostnames" {
  description = "Enable VPC DNS hostnames (required for SSM private DNS)"
  type        = bool
  default     = true
}
