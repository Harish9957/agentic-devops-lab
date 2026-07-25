output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.app.name
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API server endpoint for the EKS cluster"
  value       = aws_eks_cluster.app.endpoint
}

output "node_group_name" {
  description = "Name of the EKS managed node group running the nginx Pod"
  value       = aws_eks_node_group.app.node_group_name
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "target_group_arn" {
  description = "ARN of the ALB target group the EKS node group's instances register into"
  value       = aws_lb_target_group.app.arn
}
