data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name               = "alambeksa-example-dyn"
  kubernetes_version = "1.34"
  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  for_each = toset(var.supported_regions)
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  region = each.key
  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true
}

module "eks" {
  for_each = toset(var.supported_regions)
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.15.1"

  region = each.key
  name                   = local.name
  kubernetes_version     = local.kubernetes_version
  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}

module "lambda_eks_apply" {
  for_each = toset(var.supported_regions)
  source = "../../"

  region = each.key
  eks_cluster_name = module.eks[each.key].cluster_name

}
