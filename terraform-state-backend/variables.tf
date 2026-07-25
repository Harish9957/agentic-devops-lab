variable "aws_region" {
  description = "AWS region for the state backend"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "S3 bucket name for Terraform state. Must be globally unique on real AWS — override with a unique name before applying against real AWS (Floci has no such uniqueness constraint)."
  type        = string
  default     = "agentic-devops-lab-tfstate"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "agentic-devops-lab-tflocks"
}

variable "use_floci" {
  description = "Point the AWS provider at a local Floci emulator (http://localhost:4566) instead of real AWS. Default false — real AWS is the unchanged default behavior."
  type        = bool
  default     = false
}
