output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "public_subnet_ids" {
  description = "IDs of both public subnets (2 AZs) — use this for anything that needs multi-AZ, e.g. an ALB"
  value       = [aws_subnet.public.id, aws_subnet.public_b.id]
}

output "private_subnet_id" {
  description = "ID of the private subnet — where compute resources should be created"
  value       = aws_subnet.private.id
}
