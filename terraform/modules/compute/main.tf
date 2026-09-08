locals {
  ami_id = coalesce(var.instance_ami, one(data.aws_ami.amazon_linux_2023[*].id))
}

# No inbound rules: the instance is managed exclusively over Session Manager,
# which needs no open ports. Least-privilege by construction.
resource "aws_security_group" "ec2" {
  name        = "ec2-ssm-${var.environment}"
  description = "EC2 reachable only via Session Manager (no inbound, no SSH keys)"
  vpc_id      = var.vpc_id

  tags = {
    Name = "ec2-ssm-${var.environment}"
  }
}

resource "aws_vpc_security_group_egress_rule" "ec2_out" {
  security_group_id = aws_security_group.ec2.id
  description       = "All egress (updates + SSM plane)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "app" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = var.instance_profile
  vpc_security_group_ids = [aws_security_group.ec2.id]
  monitoring             = true
  ebs_optimized          = true

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name = "app-${var.environment}"
  }
}
