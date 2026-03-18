output "invocation_log" {
  description = "Log of the Lambda invocation execution"
  value       = jsondecode(aws_lambda_invocation.manifest_apply.result).body
}

output "lambda_role_arn" {
  description = "ARN of the IAM role used by the Lambda function"
  value       = aws_iam_role.lambda.arn
}
