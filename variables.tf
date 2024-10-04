variable "aws_region" {
  description = "AWS region to deploy the resources"
  default     = "us-east-1"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  default     = "strava_data_retriever"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to store Strava data"
  default     = "my-strava-data-bucket"
}
variable "strava_client_id" {
  description = "Strava Client ID"
  type        = string
}

variable "strava_client_secret" {
  description = "Strava Client Secret"
  type        = string
}

variable "strava_refresh_token" {
  description = "Strava Refresh Token"
  type        = string
}


