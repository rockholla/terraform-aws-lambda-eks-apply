variable "region" {
  description = "Region in which to run the Lambda, and where the destination EKS cluster for the manifest apply exists, defaults to the AWS provider region"
  type        = string
  default     = null
}

variable "eks_cluster" {
  description = "The config for the created/existing EKS cluster"
  type = object({
    name                = string
    ca_certificate_data = string
    endpoint            = string
    token               = string
  })
  sensitive = true
}

variable "lambda_package_version" {
  description = "The version of the Lambda package/artifact released separately from this module at https://github.com/rockholla/terraform-aws-lambda-eks-apply/releases"
  type        = string
  default     = "v0.0.1"
}

variable "lambda_iam_role_permissions_boundary_arn" {
  description = "Optional permissions boundary policy ARN to set on the IAM role managed by this module to execute the Lambda"
  type        = string
  default     = null
}

variable "lambda_function_timeout" {
  description = "Timeout in seconds for executions of the of the Lambda function"
  type        = number
  default     = 900
}

variable "k8s_manifest_template" {
  description = "A Kubernetes manifest template string, optionally Jinja2 (https://pypi.org/project/Jinja2/) templated to be injected with the provided secrets_data, and template_data values"
  type        = string
}

variable "template_data" {
  description = "Non-sensitive template data as a map to inject into the k8s_manifest_template using Jinja2 (https://pypi.org/project/Jinja2/)"
  type        = map(string)
  default     = {}
}

variable "template_secrets" {
  description = "A map of secret keys to secret values, which this module will stage as AWS secret manager secrets for use by the underlying Lambda"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "force_apply" {
  description = "Terraform and logic in this module will attempt to only re-invoke the manifest apply when necessary, you can use this switch to force reinvoke"
  type        = bool
  default     = false
}

