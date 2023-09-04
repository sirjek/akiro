variable "cluster_name" {
  type = string
}

variable "standard_tags" {
  default     = {}
  description = "Standard Tags to apply to all Resources"
  type        = map(string)
}