# Container Image for use in Lambda for Applying a Templated Kubernetes Manifest to an EKS Cluster

This directory contains the source for the [container image to be use by AWS Lambda](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html) in the top-level Terraform module. You can use this image directly without using the module as well.

## Inputs to the AWS Lambda function

> [!NOTE]
> The IAM role used to execute your AWS Lambda function must have permissions to access any secret names passed to the function

### Required Inputs

* `cluster_ca_certificate_data`: the EKS cluster CA certificate data, typical bas64 encoded version of it
* `cluster_endpoint`: the EKS cluster endpoint accessible from the Lambda function
* `cluster_token_secret_name`: The AWS secrets manager secret name, storing a temporary token to authenticate to the cluster
* `manifest_template_base64`: The string (base64 encoded) that is a YAML manifest to apply, optionally templated via Jinja2

### Other inputs provided to the lambda function can be used as top-level Jinja2 template values as defined in the above `manifest_template_base64`. For example

If I pass the following additional values as inputs to the lambda function:

* `namespace`
* `resource_name`
* `enable_feature`

And I have a pre-encoded `manifest_template_base64` value like:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: "{{ namespace }}"

---

apiVersion: v1
kind: ConfigMap
metadata:
  name: "{{ resource_name }}"
  namespace: "{{ namespace }}"
data:
  ENABLE_FEATURE: "{{ enable_feature }}"
```

The manifest will get rendered with the values filled in from the inputs.

## Special Handling for Secrets in the Lambda Inputs

if you provide an input `secret_names`, the function will loop over each of these key/values, and attempt to read AWS secrets manager secrets by name for each value. Once the value is retrieved, it will populate the top level event object of the same key with that value. For example, if I provide the following to the function inputs:

```
secret_names = {
  my_secret_value = "name-of-my-aws-secrets-manager-secret"
}
```

The function will go get that value from the related secrets manager secret named `name-of-my-aws-secrets-manager-secret`, and then populate the top level inputs object at `my_secret_value` with that value, so you could use it in your manifest template like:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: "{{ resource_name }}"
  namespace: "{{ namespace }}"
data:
  MY_SECRET_VALUE: "{{ my_secret_value }}"
```
