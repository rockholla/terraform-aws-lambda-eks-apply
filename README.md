<!-- BEGIN_TF_DOCS -->
# AWS Lambda EKS Apply Terraform Module

This module wraps up some functionality to dynamically apply Kubernetes templated manifests to an EKS cluster via normal Terraform provisioning flows.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.28 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cluster_auth_secret"></a> [cluster\_auth\_secret](#module\_cluster\_auth\_secret) | terraform-aws-modules/secrets-manager/aws | 2.1.0 |
| <a name="module_secrets_data_secrets"></a> [secrets\_data\_secrets](#module\_secrets\_data\_secrets) | terraform-aws-modules/secrets-manager/aws | 2.1.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_lambda_function.manifest_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_invocation.manifest_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster_auth.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_policy_document.lambda_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_eks_cluster_name"></a> [eks\_cluster\_name](#input\_eks\_cluster\_name) | The name of the EKS cluster where the Lambda will apply the manifest | `string` | n/a | yes |
| <a name="input_k8s_manifest_template"></a> [k8s\_manifest\_template](#input\_k8s\_manifest\_template) | A Kubernetes manifest template string, optionally Jinja2 (https://pypi.org/project/Jinja2/) templated to be injected with the provided secrets\_data, and template\_data values | `string` | n/a | yes |
| <a name="input_lambda_iam_role_permissions_boundary_arn"></a> [lambda\_iam\_role\_permissions\_boundary\_arn](#input\_lambda\_iam\_role\_permissions\_boundary\_arn) | Optional permissions boundary policy ARN to set on the IAM role managed by this module to execute the Lambda | `string` | `null` | no |
| <a name="input_lambda_image"></a> [lambda\_image](#input\_lambda\_image) | The container image to use for running the Lambda | `string` | `"rockholla/lambda-eks-apply:latest"` | no |
| <a name="input_region"></a> [region](#input\_region) | Region in which to run the Lambda, and where the destination EKS cluster for the manifest apply exists, defaults to the AWS provider region | `string` | `null` | no |
| <a name="input_secrets_data"></a> [secrets\_data](#input\_secrets\_data) | A map of secret keys to secret values, which this module will stage as AWS secret manager secrets for use by the underlying Lambda | `map(string)` | `{}` | no |
| <a name="input_template_data"></a> [template\_data](#input\_template\_data) | Non-sensitive template data as a map to inject into the k8s\_manifest\_template using Jinja2 (https://pypi.org/project/Jinja2/) | `map(string)` | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->