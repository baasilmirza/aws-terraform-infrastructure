output "vpc_id" {
  description = "VPC id"
  value       = module.network.vpc_id
}

output "instance_id" {
  description = "EC2 instance id"
  value       = module.compute.instance_id
}

output "instance_private_ip" {
  description = "Private IP of the EC2 instance"
  value       = module.compute.private_ip
}

output "instance_availability_zone" {
  description = "Availability zone of the EC2 instance"
  value       = module.compute.availability_zone
}

output "ec2_instance_profile" {
  description = "IAM instance profile attached to the EC2 instance"
  value       = module.iam.instance_profile_name
}

output "ops_role_arn" {
  description = "Least-privilege ops role ARN (SSM session access)"
  value       = module.iam.ops_role_arn
}

output "ssm_connect" {
  description = "Command to open a Session Manager shell on the instance"
  value       = "aws ssm start-session --target ${module.compute.instance_id}"
}
