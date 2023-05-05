variable "public_subnet_cidrs" {
 type        = list(string)
 description = "Public Subnet CIDR values"
 default     = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
}

variable "private_subnet_cidrs" {
 type        = list(string)
 description = "Private Subnet CIDR values"
 default     = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"]
}

variable "azs" {
 type        = list(string)
 description = "Availability Zones"
 default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"

}

variable "image" {
  type        = string
  description = "Grafana image"
  default     = "grafana/grafana:latest"
}

variable "ecs_cpu" {
  type        = number
  description = "The number of CPU units to allocate to the ECS Service."
  default     = 2
}

variable "ecs_memory" {
  type        = number
  description = "How much memory, in MB, to give the ECS Service."
  default     = 1024
}
