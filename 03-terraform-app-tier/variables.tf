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
  description = "EC2 instance type for the app-tier instance"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance. Default is a recent Amazon Linux 2023 AMI in us-east-1 — override for other regions. Not validated against a real catalog during `plan` (only `apply` against real AWS checks it actually exists); Floci doesn't validate it at all."
  type        = string
  default     = "ami-0c101f26f147fa7fd"
}

variable "environment" {
  description = "Environment tag applied to all resources (env = ...)"
  type        = string
  default     = "dev"
}
