variable "aws_region" {
  description = "AWS region to create resources in — must match the region 02-terraform-vpc was applied in"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "agentic-devops-lab-03"
}

variable "use_floci" {
  description = "Point the AWS provider (and the remote_state read of 02's outputs) at a local Floci emulator (http://localhost:4566) instead of real AWS. Default false — real AWS is the unchanged default behavior."
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "EC2 instance type for the EKS node group's worker nodes"
  type        = string
  default     = "t3.small"
}

variable "environment" {
  description = "Environment tag applied to all resources (env = ...)"
  type        = string
  default     = "dev"
}

variable "app_port" {
  description = "Port the ALB listens on externally (what users hit)"
  type        = number
  default     = 80
}

variable "node_port" {
  description = "NodePort the nginx Kubernetes Service exposes on each EKS worker node. The ALB's target group forwards here, not to app_port directly — nginx runs as a Pod on the cluster, not a bare process on the host."
  type        = number
  default     = 30080
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes in the EKS node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes in the EKS node group"
  type        = number
  default     = 1
}
