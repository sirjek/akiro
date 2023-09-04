module "eks" {
  depends_on = [ module.vpc]
  source = "./eks"
  cluster_name = var.cluster_name
  eks_instance_types = var.eks_instance_types
  vpc_id = module.vpc.vpc_id
  account_id = var.account_id
  subnet_ids = [module.vpc.id_1, module.vpc.id_2]
  standard_tags = var.tags

}