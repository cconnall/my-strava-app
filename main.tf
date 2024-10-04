provider "aws" {
  region = var.aws_region
}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
      }
    ],
  })
}

# IAM Policy for Lambda to access Secrets Manager and S3
resource "aws_iam_policy" "lambda_secrets_manager_s3_policy" {
  name        = "lambda_secrets_manager_s3_policy"
  description = "Allows Lambda to read from Secrets Manager and write to S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "secretsmanager:GetSecretValue",
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:StravaSecrets-*",
        Effect   = "Allow"
      },
      {
        Action   = "secretsmanager:UpdateSecret",  # Allow Lambda to update the secret
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:StravaSecrets-*",
        Effect   = "Allow"
      },
      {
        Action   = "s3:PutObject",
        Effect   = "Allow",
        Resource = "arn:aws:s3:::${aws_s3_bucket.lambda_code_bucket.bucket}/*",
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*",
      }
    ]
  })
}

# Attach the Secrets Manager and S3 policy to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_secrets_manager_s3_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_secrets_manager_s3_policy.arn
}

# S3 Bucket for Lambda Code Storage
resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket = var.s3_bucket_name
}

# Strava Secrets in Secrets Manager
resource "aws_secretsmanager_secret" "strava_secrets" {
  name = "StravaSecrets"
}

resource "aws_secretsmanager_secret_version" "strava_secrets_version" {
  secret_id     = aws_secretsmanager_secret.strava_secrets.id
  secret_string = jsonencode({
    STRAVA_CLIENT_ID     = var.strava_client_id,
    STRAVA_CLIENT_SECRET = var.strava_client_secret,
    STRAVA_REFRESH_TOKEN = var.strava_refresh_token
  })
}

# Lambda Function to Fetch Strava Data
resource "aws_lambda_function" "strava_fetch_lambda" {
  function_name = var.lambda_function_name
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  s3_bucket     = var.s3_bucket_name 
  s3_key        = "lambda_function.zip"
  role          = aws_iam_role.lambda_exec_role.arn
  timeout       = 10

  environment {
    variables = {
      STRAVA_CLIENT_ID     = jsondecode(data.aws_secretsmanager_secret_version.strava_secrets_version.secret_string)["STRAVA_CLIENT_ID"],
      STRAVA_CLIENT_SECRET = jsondecode(data.aws_secretsmanager_secret_version.strava_secrets_version.secret_string)["STRAVA_CLIENT_SECRET"],
      STRAVA_REFRESH_TOKEN = jsondecode(data.aws_secretsmanager_secret_version.strava_secrets_version.secret_string)["STRAVA_REFRESH_TOKEN"],
      S3_BUCKET_NAME       = var.s3_bucket_name  
    }
  }
}

# Data source to access the secret from Secrets Manager
data "aws_secretsmanager_secret_version" "strava_secrets_version" {
  secret_id = aws_secretsmanager_secret.strava_secrets.id
}

# CloudWatch Event Rule for Daily Trigger (12 PM EST)
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "daily-strava-fetch"
  description         = "Trigger Lambda to fetch Strava data daily at 12 PM EST"
  schedule_expression = "cron(0 17 * * ? *)" # 12 PM EST considering UTC timezone.
}

# Target the Lambda function with the daily trigger
resource "aws_cloudwatch_event_target" "trigger_lambda_daily" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "StravaFetchLambda"
  arn       = aws_lambda_function.strava_fetch_lambda.arn
}

# Allow CloudWatch to invoke the Lambda function
resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.strava_fetch_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

# Data source to get the current AWS account ID
data "aws_caller_identity" "current" {}