# My Strava App

## Overview

`my-strava-app` is an AWS Lambda-based application that retrieves activity data from the Strava API and stores the data in an S3 bucket. The application securely manages Strava API credentials using AWS Secrets Manager and runs daily to fetch the latest activities, making it easier to manage and analyze your fitness data.

## Project Structure

my-strava-app/
├── lambda_function.py        # The main Lambda function that fetches Strava data
├── terraform/                # Terraform scripts for AWS infrastructure
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Variables for Terraform configurations
│   ├── outputs.tf            # Outputs from Terraform resources
│   └── provider.tf           # AWS provider setup
├── README.md                 # Project documentation
├── requirements.txt          # Python dependencies for the Lambda function
└── lambda_function.zip       # Packaged Lambda function
