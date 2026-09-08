output "instance_role_arn" {
  description = "ARN of the EC2 instance role"
  value       = aws_iam_role.ec2_ssm.arn
}

output "instance_role_name" {
  description = "Name of the EC2 instance role"
  value       = aws_iam_role.ec2_ssm.name
}

output "instance_profile_name" {
  description = "IAM instance profile name to attach to the EC2 instance"
  value       = aws_iam_instance_profile.ec2_ssm.name
}

output "ops_role_arn" {
  description = "ARN of the least-privilege ops role"
  value       = aws_iam_role.ops.arn
}

output "ops_role_name" {
  description = "Name of the least-privilege ops role"
  value       = aws_iam_role.ops.name
}
