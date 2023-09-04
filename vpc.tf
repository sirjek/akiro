module "vpc" {
  source = "./vpc"
  cluster_name = var.cluster_name
  standard_tags = var.tags
}