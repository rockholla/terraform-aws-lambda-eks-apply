<!-- BEGIN_TF_DOCS -->
# AWS Lambda EKS Apply Terraform Module

This module wraps up some functionality to dynamically apply Kubernetes templated manifests to an EKS cluster via normal Terraform provisioning flows.

We will build out these docs as we move forward, but see the [example directory](./examples/) for usage in the meantime.

## Why?

* Provisioning an EKS cluster along w/ installing some basic things in to it to start is hard
* It's impossible if you use Terraform in dynamic ways
* People want a solution to this problem w/o using the kubectl, kubernetes, etc. providers...
* [A provider exists to address this problem](https://github.com/jmorris0x0/terraform-provider-k8sconnect)
* But maybe we don't need a full provider, just this module for specific needs like EKS

> [!WARN]
> This module is not meant to install complex workloads or other resources into Kubernetes. Keep using other tools for that. **This is primarily meant to be used for bootstrapping chicken/egg type resources into your cluster so you can have the other deployment tools take over from there.**


## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.28 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_template_secrets"></a> [template\_secrets](#module\_template\_secrets) | terraform-aws-modules/secrets-manager/aws | 2.1.0 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.manifest_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.lambda_role_basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.manifest_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_invocation.manifest_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_s3_bucket.lambda_package](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_object_copy.lambda_package](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object_copy) | resource |
| [aws_secretsmanager_secret.cluster_auth_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_policy.cluster_auth_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_policy) | resource |
| [aws_secretsmanager_secret_version.cluster_auth_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [terraform_data.apply_trigger](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_iam_policy_document.cluster_auth_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.lambda_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_delete_manifest"></a> [delete\_manifest](#input\_delete\_manifest) | By default, the manifest will be kubectl applied via the Lambda, set this to run a kubectl delete instead | `bool` | `false` | no |
| <a name="input_eks_cluster"></a> [eks\_cluster](#input\_eks\_cluster) | The config for the created/existing EKS cluster | <pre>object({<br/>    name                = string<br/>    ca_certificate_data = string<br/>    endpoint            = string<br/>    token               = string<br/>  })</pre> | n/a | yes |
| <a name="input_fail_on_apply_errors"></a> [fail\_on\_apply\_errors](#input\_fail\_on\_apply\_errors) | Whether or not to let this module fail/handle failures in the apply Lambda invocation | `bool` | `true` | no |
| <a name="input_force_apply"></a> [force\_apply](#input\_force\_apply) | Terraform and logic in this module will attempt to only re-invoke the manifest apply when necessary, you can use this switch to force reinvoke | `bool` | `false` | no |
| <a name="input_k8s_manifest_template"></a> [k8s\_manifest\_template](#input\_k8s\_manifest\_template) | A Kubernetes manifest template string, optionally Jinja2 (https://pypi.org/project/Jinja2/) templated to be injected with the provided secrets\_data, and template\_data values | `string` | n/a | yes |
| <a name="input_lambda_function_timeout"></a> [lambda\_function\_timeout](#input\_lambda\_function\_timeout) | Timeout in seconds for executions of the of the Lambda function | `number` | `900` | no |
| <a name="input_lambda_iam_role_permissions_boundary_arn"></a> [lambda\_iam\_role\_permissions\_boundary\_arn](#input\_lambda\_iam\_role\_permissions\_boundary\_arn) | Optional permissions boundary policy ARN to set on the IAM role managed by this module to execute the Lambda | `string` | `null` | no |
| <a name="input_lambda_package_version"></a> [lambda\_package\_version](#input\_lambda\_package\_version) | The version of the Lambda function (https://github.com/rockholla/terraform-aws-lambda-eks-apply/tree/main/lambda) package/artifact released separately from this module to Github releases/S3 for use by this module | `string` | `"v0.0.3"` | no |
| <a name="input_region"></a> [region](#input\_region) | Region in which to run the Lambda, and where the destination EKS cluster for the manifest apply exists, defaults to the AWS provider region | `string` | `null` | no |
| <a name="input_template_data"></a> [template\_data](#input\_template\_data) | Non-sensitive template data as a map to inject into the k8s\_manifest\_template using Jinja2 (https://pypi.org/project/Jinja2/) | `map(string)` | `{}` | no |
| <a name="input_template_secrets"></a> [template\_secrets](#input\_template\_secrets) | A map of secret keys to secret values, which this module will stage as AWS secret manager secrets for use by the underlying Lambda | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_invocation_log"></a> [invocation\_log](#output\_invocation\_log) | Log of the Lambda invocation execution |
<!-- END_TF_DOCS -->