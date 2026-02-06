data "aws_region" "current" {}

locals {
  region                    = var.region != null ? var.region : data.aws_region.current.region
  cluster_token_secret_name = "${var.eks_cluster.name}-apply-manifest-token"
  template_secrets_keys     = nonsensitive(keys(var.template_secrets))
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid     = "LambdaEKSApplyAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name        = "${var.eks_cluster.name}-${local.region}-apply-manifest-lambda"
  description = "Role w/ permissions execute the Lambda to apply manifests to the EKS cluster ${var.eks_cluster.name}"

  assume_role_policy    = data.aws_iam_policy_document.lambda_assume_role.json
  permissions_boundary  = var.lambda_iam_role_permissions_boundary_arn
  force_detach_policies = true
}

locals {
  secrets_policy_statements = {
    read = {
      sid = "AllowReadFromLambdaEKSApplyIAMRole"
      principals = [{
        type        = "AWS"
        identifiers = [aws_iam_role.lambda.arn]
      }]
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["*"]
    }
  }
}

module "cluster_auth_secret" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "2.1.0"

  region                  = local.region
  name_prefix             = local.cluster_token_secret_name
  description             = "Temporary EKS cluster auth token for ${var.eks_cluster.name} cluster, for use by the Lambda EKS apply function"
  recovery_window_in_days = 30
  secret_string           = var.eks_cluster.token

  create_policy       = true
  block_public_policy = true
  policy_statements   = local.secrets_policy_statements
}

module "template_secrets" {
  for_each = toset(local.template_secrets_keys)
  source   = "terraform-aws-modules/secrets-manager/aws"
  version  = "2.1.0"

  region                  = local.region
  name_prefix             = each.key
  description             = "Secret for ${each.key} in the Lambda to apply a rendered manifest to the EKS cluster ${var.eks_cluster.name}"
  recovery_window_in_days = 30
  secret_string           = var.template_secrets[each.key]

  create_policy       = true
  block_public_policy = true
  policy_statements   = local.secrets_policy_statements
}

locals {
  template_data = merge(var.template_data, {
    cluster_ca_certificate_data = var.eks_cluster.ca_certificate_data
    cluster_endpoint            = var.eks_cluster.endpoint
    cluster_token_secret_name   = module.cluster_auth_secret.secret_name
    cluster_name                = var.eks_cluster.name
    }, {
    secret_names = { for key, template_secret in module.template_secrets : key => template_secret.secret_name }
  })
}

locals {
  lambda_zip_filename = "${path.cwd}/lambda-${var.lambda_package_version}.zip"
}

resource "utility_file_downloader" "lambda_release" {
  url      = "https://github.com/rockholla/terraform-aws-lambda-eks-apply/releases/download/lambda%2F${var.lambda_package_version}/lambda-${var.lambda_package_version}.zip"
  filename = local.lambda_zip_filename

  headers = {
    Accept = "application/vnd.github+json"
  }
}

resource "aws_lambda_function" "manifest_apply" {
  region        = local.region
  function_name = "${var.eks_cluster.name}-apply-manifest"
  timeout       = var.lambda_function_timeout
  architectures = ["x86_64"]
  filename      = local.lambda_zip_filename
  runtime       = "python3.14"
  handler       = "main.handler"

  role = aws_iam_role.lambda.arn
}

resource "aws_lambda_invocation" "manifest_apply" {
  region        = local.region
  function_name = aws_lambda_function.manifest_apply.function_name

  input = jsonencode(local.template_data)
}
