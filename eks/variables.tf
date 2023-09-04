variable "cluster_name" {
  type = string
}
variable "vpc_id" {
  type = string
}

variable "account_id" {
  type = string
}
variable "eks_instance_types" {
  type = list(string)
}

variable "subnet_ids" {
  type = list(string)
}

variable "standard_tags" {
  default     = {}
  description = "Standard Tags to apply to all Resources"
  type        = map(string)
}