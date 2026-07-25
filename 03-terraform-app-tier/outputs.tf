output "asg_name" {
  description = "Name of the Auto Scaling Group managing the app-tier instances"
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "ID of the launch template the ASG uses to launch instances"
  value       = aws_launch_template.app.id
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "target_group_arn" {
  description = "ARN of the ALB target group the ASG registers instances into"
  value       = aws_lb_target_group.app.arn
}
