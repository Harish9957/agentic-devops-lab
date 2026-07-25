variable "aws_region" {
  description = "AWS region to create the VPC in"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "agentic-devops-lab-02"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  description = "CIDR block for the second public subnet — ALBs require subnets in at least 2 AZs, which a single public subnet can't satisfy"
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet — where compute resources (EC2, etc.) actually go"
  type        = string
  default     = "10.0.2.0/24"
}

variable "public_availability_zone" {
  description = "Availability zone for the public subnet"
  type        = string
  default     = "us-east-1a"
}

variable "public_availability_zone_b" {
  description = "Availability zone for the second public subnet — deliberately different from the first public subnet's AZ (and from the private subnet's), so ALBs can satisfy AWS's 2-AZ requirement"
  type        = string
  default     = "us-east-1c"
}

variable "private_availability_zone" {
  description = "Availability zone for the private subnet — deliberately different from the public subnet's AZ, so the private subnet survives an outage in the public subnet's AZ"
  type        = string
  default     = "us-east-1b"
}

variable "use_floci" {
  description = "Point the AWS provider at a local Floci emulator (http://localhost:4566) instead of real AWS. Default false — real AWS is the unchanged default behavior."
  type        = bool
  default     = false
}
