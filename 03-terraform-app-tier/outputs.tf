output "ec2_instance_id" {
  description = "ID of the EC2 instance in the private subnet"
  value       = aws_instance.app.id
}

output "ec2_private_ip" {
  description = "Private IP of the EC2 instance — reachable only from inside the VPC, no public IP by design"
  value       = aws_instance.app.private_ip
}
