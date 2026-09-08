locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

module "network" {
  source = "./modules/network"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = var.environment
}

module "iam" {
  source = "./modules/iam"

  environment         = var.environment
  region              = var.aws_region
  ssm_session_allowed = var.ssm_session_allowed
}

module "compute" {
  source = "./modules/compute"

  vpc_id           = module.network.vpc_id
  subnet_id        = module.network.private_subnet_ids[0]
  instance_type    = var.instance_type
  instance_ami     = var.instance_ami
  environment      = var.environment
  instance_profile = module.iam.instance_profile_name
}

# Session Manager VPC endpoints (interface) so a private instance with no
# public IP and no NAT can reach the SSM control plane.
resource "aws_security_group" "ssm_endpoints" {
  name        = "ssm-vpc-endpoints-${var.environment}"
  description = "Allow HTTPS from EC2 compute SG to SSM VPC endpoints"
  vpc_id      = module.network.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ssm_https_from_ec2" {
  security_group_id            = aws_security_group.ssm_endpoints.id
  description                  = "HTTPS from app EC2"
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.compute.security_group_id
}

resource "aws_vpc_security_group_egress_rule" "ssm_endpoints_out" {
  security_group_id = aws_security_group.ssm_endpoints.id
  description       = "All egress"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = module.network.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.network.private_subnet_ids[0]]
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = module.network.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.network.private_subnet_ids[0]]
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id              = module.network.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.network.private_subnet_ids[0]]
  security_group_ids  = [aws_security_group.ssm_endpoints.id]
  private_dns_enabled = true
}
