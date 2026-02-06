data "aws_region" "current" {}

locals {
  secret_name_suffix               = "4eks9"
  region                           = var.region != null ? var.region : data.aws_region.current.region
  cluster_name                     = nonsensitive(var.eks_cluster.name)
  cluster_token_secret_name_prefix = "${local.cluster_name}-a"
  template_secrets_keys            = nonsensitive(keys(var.template_secrets))
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
  name        = "${local.cluster_name}-${local.region}-apply-manifest-lambda"
  description = "Role w/ permissions execute the Lambda to apply manifests to the EKS cluster ${local.cluster_name}"

  assume_role_policy    = data.aws_iam_policy_document.lambda_assume_role.json
  permissions_boundary  = var.lambda_iam_role_permissions_boundary_arn
  force_detach_policies = true
}

resource "aws_iam_role_policy_attachment" "lambda_role_basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
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
  name                    = "${local.cluster_token_secret_name_prefix}-${local.secret_name_suffix}"
  description             = "Temporary EKS cluster auth token for ${local.cluster_name} cluster, for use by the Lambda EKS apply function"
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
  name                    = "${each.key}-${local.secret_name_suffix}"
  description             = "Secret for ${each.key} in the Lambda to apply a rendered manifest to the EKS cluster ${local.cluster_name}"
  recovery_window_in_days = 30
  secret_string           = var.template_secrets[each.key]

  create_policy       = true
  block_public_policy = true
  policy_statements   = local.secrets_policy_statements
}

locals {
  template_data = merge(var.template_data, {
    manifest_template_base64    = base64encode(var.k8s_manifest_template)
    cluster_ca_certificate_data = var.eks_cluster.ca_certificate_data
    cluster_endpoint            = nonsensitive(var.eks_cluster.endpoint)
    cluster_token_secret_name   = module.cluster_auth_secret.secret_name
    cluster_name                = local.cluster_name
    }, {
    secret_names = { for key, template_secret in module.template_secrets : key => template_secret.secret_name }
  })
}

resource "utility_file_downloader" "lambda_release" {
  url      = "https://github.com/rockholla/terraform-aws-lambda-eks-apply/releases/download/lambda%2F${var.lambda_package_version}/lambda-${var.lambda_package_version}.zip"
  filename = "${path.cwd}/lambda-${var.lambda_package_version}.zip"

  headers = {
    Accept = "application/vnd.github+json"
  }
}

resource "aws_cloudwatch_log_group" "manifest_apply" {
  name              = "/aws/lambda/${local.cluster_name}-apply-manifest"
  retention_in_days = 5
}

resource "aws_lambda_function" "manifest_apply" {
  region        = local.region
  function_name = "${local.cluster_name}-apply-manifest"
  timeout       = var.lambda_function_timeout
  architectures = ["x86_64"]
  filename      = utility_file_downloader.lambda_release.filename
  runtime       = "python3.14"
  handler       = "main.handler"

  role = aws_iam_role.lambda.arn

  logging_config {
    log_format            = "JSON"
    application_log_level = "INFO"
    system_log_level      = "WARN"
  }

  depends_on = [aws_cloudwatch_log_group.manifest_apply]
}

resource "aws_lambda_invocation" "manifest_apply" {
  region        = local.region
  function_name = aws_lambda_function.manifest_apply.function_name

  input = jsonencode(local.template_data)

  lifecycle {
    postcondition {
      condition     = jsondecode(self.result).statusCode == 200
      error_message = "Lambda function invocation failed, full inputs to the function: ${nonsensitive(jsonencode(local.template_data))}"
    }
  }
}
