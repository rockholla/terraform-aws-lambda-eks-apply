data "aws_region" "current" {}

locals {
  region                           = var.region != null ? var.region : data.aws_region.current.region
  cluster_name                     = nonsensitive(var.eks_cluster.name)
  cluster_token_secret_name_prefix = "${local.cluster_name}-lambda-eks-apply-token-"
  template_secrets_keys            = nonsensitive(keys(var.template_secrets))
  apply_trigger                    = var.force_apply ? timestamp() : base64encode("${jsonencode(local.template_data)}${var.k8s_manifest_template}")
}

resource "terraform_data" "apply_trigger" {
  triggers_replace = local.apply_trigger
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
      sid    = "AllowReadFromLambdaEKSApplyIAMRole"
      effect = "Allow"
      principals = [{
        type        = "AWS"
        identifiers = [aws_iam_role.lambda.arn]
      }]
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["*"]
    }
  }
}

resource "aws_secretsmanager_secret" "cluster_auth_secret" {
  region                  = local.region
  description             = "Temporary EKS cluster auth token for ${local.cluster_name} cluster, for use by the Lambda EKS apply function"
  name_prefix             = local.cluster_token_secret_name_prefix
  recovery_window_in_days = 7
}

data "aws_iam_policy_document" "cluster_auth_secret" {
  dynamic "statement" {
    for_each = local.secrets_policy_statements

    content {
      sid       = statement.value.sid
      actions   = statement.value.actions
      effect    = statement.value.effect
      resources = statement.value.resources

      dynamic "principals" {
        for_each = statement.value.principals != null ? statement.value.principals : []

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }
    }
  }
}

resource "aws_secretsmanager_secret_policy" "cluster_auth_secret" {
  region              = local.region
  block_public_policy = true
  policy              = data.aws_iam_policy_document.cluster_auth_secret.json
  secret_arn          = aws_secretsmanager_secret.cluster_auth_secret.arn
}

resource "aws_secretsmanager_secret_version" "cluster_auth_secret" {
  region        = local.region
  secret_id     = aws_secretsmanager_secret.cluster_auth_secret.id
  secret_string = var.eks_cluster.token

  # all normal operations that change the secret_string will be ignored
  # but the full resource will be replaced when an apply of the manifest
  # needs to happen
  lifecycle {
    ignore_changes = [
      secret_string
    ]
    replace_triggered_by = [
      terraform_data.apply_trigger
    ]
  }
}

module "template_secrets" {
  for_each = toset(local.template_secrets_keys)
  source   = "terraform-aws-modules/secrets-manager/aws"
  version  = "2.1.0"

  region                  = local.region
  name_prefix             = "${each.key}-"
  description             = "Secret for ${each.key} in the Lambda to apply a rendered manifest to the EKS cluster ${local.cluster_name}"
  recovery_window_in_days = 7
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
    cluster_token_secret_name   = aws_secretsmanager_secret.cluster_auth_secret.name
    cluster_name                = local.cluster_name
    }, {
    secret_names = { for key, template_secret in module.template_secrets : key => template_secret.secret_name }
  })
}

locals {
  lambda_function_name  = "${local.cluster_name}-apply-manifest"
  lambda_package_s3_key = "lambda-${var.lambda_package_version}.zip"
}

resource "aws_s3_bucket" "lambda_package" {
  region        = local.region
  bucket_prefix = substr(local.cluster_name, 0, 37)
}

resource "aws_s3_object_copy" "lambda_package" {
  region = local.region
  bucket = aws_s3_bucket.lambda_package.id
  key    = local.lambda_package_s3_key
  source = "rockholla-terraform-aws-lambda-eks-apply/lambda-releases/${local.lambda_package_s3_key}"
}

resource "aws_cloudwatch_log_group" "manifest_apply" {
  region            = local.region
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = 5
}

resource "aws_lambda_function" "manifest_apply" {
  region        = local.region
  function_name = local.lambda_function_name
  timeout       = var.lambda_function_timeout
  architectures = ["x86_64"]
  s3_bucket     = aws_s3_bucket.lambda_package.id
  s3_key        = local.lambda_package_s3_key
  runtime       = "python3.14"
  handler       = "main.handler"

  role = aws_iam_role.lambda.arn

  logging_config {
    log_format            = "JSON"
    application_log_level = "INFO"
    system_log_level      = "WARN"
  }

  depends_on = [
    aws_cloudwatch_log_group.manifest_apply,
    aws_s3_object_copy.lambda_package
  ]
}

resource "aws_lambda_invocation" "manifest_apply" {
  region        = local.region
  function_name = aws_lambda_function.manifest_apply.function_name

  input = jsonencode(local.template_data)

  lifecycle {
    postcondition {
      condition     = jsondecode(self.result).statusCode == 200 || !var.fail_on_apply_errors
      error_message = "Lambda function invocation failed, full inputs to the function: ${nonsensitive(jsonencode(local.template_data))}"
    }
    replace_triggered_by = [
      terraform_data.apply_trigger
    ]
  }
}
