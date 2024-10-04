output "lambda_function_name" {
  value = aws_lambda_function.strava_fetch_lambda.function_name
}

output "s3_bucket_name" {
  value = var.s3_bucket_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.strava_fetch_lambda.arn
}


output "lambda_exec_role_arn" {
  value = aws_iam_role.lambda_exec_role.arn
}

output "strava_secrets_arn" {
  value = aws_secretsmanager_secret.strava_secrets.arn
}

output "strava_secrets_version_arn" {
  value = aws_secretsmanager_secret_version.strava_secrets_version.arn
}
