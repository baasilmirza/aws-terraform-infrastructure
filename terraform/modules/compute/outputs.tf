output "instance_id" {
  description = "EC2 instance id"
  value       = aws_instance.app.id
}

output "instance_arn" {
  description = "EC2 instance ARN"
  value       = aws_instance.app.arn
}

output "private_ip" {
  description = "Private IP of the instance"
  value       = aws_instance.app.private_ip
}

output "availability_zone" {
  description = "Availability zone of the instance"
  value       = aws_instance.app.availability_zone
}

output "security_group_id" {
  description = "EC2 security group id"
  value       = aws_security_group.ec2.id
}
