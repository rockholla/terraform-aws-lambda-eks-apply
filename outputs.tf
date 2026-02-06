output "invocation_log" {
  description = "Log of the Lambda invocation execution"
  value       = jsondecode(aws_lambda_invocation.manifest_apply.result).body
}
