# My Strava App

## Overview

`my-strava-app` is an AWS Lambda-based application that retrieves activity data from the Strava API and stores the data in an S3 bucket. The application securely manages Strava API credentials using AWS Secrets Manager and runs daily to fetch the latest activities, making it easier to manage and analyze your fitness data.

## Project Structure


`my-strava-app`

├── lambda_function.py        
├── terraform/                
│   ├── main.tf              
│   ├── variables.tf          
│   ├── outputs.tf            
│   └── provider.tf           
├── README.md                 
├── requirements.txt          
└── lambda_function.zip       