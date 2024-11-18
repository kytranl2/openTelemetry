variable "aws_region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "demo-cluster"
}

variable "vpc_id" {
  description = "VPC ID where ECS services will be deployed"
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}
