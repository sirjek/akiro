variable "cluster_name" {
  type = string
}

variable "eks_instance_types" {
  type = list(string)
}

variable "account_id" {
  type = string

}
variable "tags" {
  default     = {}
  description = "Standard Tags to apply to all Resources"
  type        = map(string)
}