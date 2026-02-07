locals {
  name = "alambeksa-example-dyn"
}

data "aws_availability_zones" "available" {
  for_each = toset(var.supported_regions)
  region   = each.key
}

module "vpc" {
  for_each = toset(var.supported_regions)
  source   = "terraform-aws-modules/vpc/aws"
  version  = "~> 6.0"

  region = each.key
  name   = local.name
  cidr   = "10.0.0.0/16"

  map_public_ip_on_launch = true
  azs                     = slice(data.aws_availability_zones.available[each.key].names, 0, 3)
  private_subnets         = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets          = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
  }
}

module "eks" {
  for_each = toset(var.supported_regions)
  source   = "terraform-aws-modules/eks/aws"
  version  = "~> 21.15.1"

  region                 = each.key
  name                   = local.name
  kubernetes_version     = "1.35"
  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc[each.key].vpc_id
  subnet_ids = concat(module.vpc[each.key].private_subnets, module.vpc[each.key].public_subnets)
}

data "aws_eks_cluster_auth" "cluster" {
  for_each = toset(var.supported_regions)
  region   = each.key
  name     = module.eks[each.key].cluster_name
}

module "lambda_eks_apply" {
  for_each = toset(var.supported_regions)
  source   = "../../"

  region = each.key
  eks_cluster = {
    name                = module.eks[each.key].cluster_name
    ca_certificate_data = module.eks[each.key].cluster_certificate_authority_data
    endpoint            = module.eks[each.key].cluster_endpoint
    token               = data.aws_eks_cluster_auth.cluster[each.key].token
  }
  k8s_manifest_template = file("${path.module}/manifest.tmpl.yaml")
  template_data = {
    nginx_deployment_name  = "test-deployment"
    nginx_deployment_image = "nginx:1.29"
  }
  template_secrets = {
    deployment_secret = "bXktc2VjcmV0Cg=="
  }
  force_apply = var.force_apply
}

output "apply_logs" {
  value = { for region, result in module.lambda_eks_apply : region => result.invocation_log }
}

