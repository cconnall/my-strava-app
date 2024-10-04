import os
import json
import boto3
import requests
import logging
from requests.exceptions import RequestException
from datetime import datetime

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize AWS clients
secrets_manager_client = boto3.client('secretsmanager')
s3_client = boto3.client('s3')

# Function to fetch secrets from AWS Secrets Manager
def fetch_from_secret_manager(secret_name):
    try:
        response = secrets_manager_client.get_secret_value(SecretId=secret_name)
        secret_string = response['SecretString']
        secrets = json.loads(secret_string)
        return secrets
    except Exception as e:
        logger.error(f"Error fetching secrets: {e}")
        raise

# Function to refresh Strava access token using refresh token
def fetch_strava_access_token():
    try:
        # Fetch Strava credentials from Secrets Manager
        secrets = fetch_from_secret_manager("StravaSecrets")
        logger.info(f"Fetched secrets: {secrets}")

        # Strava token refresh endpoint
        url = 'https://www.strava.com/oauth/token'
        data = {
            'client_id': secrets['STRAVA_CLIENT_ID'],
            'client_secret': secrets['STRAVA_CLIENT_SECRET'],
            'grant_type': 'authorization_code',
            'refresh_token': secrets['STRAVA_REFRESH_TOKEN']
        }

        logger.info(f"Requesting new access token with data: {data}")

        response = requests.post(url, data=data)
        response.raise_for_status()  # Raises an exception for 4XX/5XX responses

        response_json = response.json()
        logger.info(f"Response from Strava API when fetching access token: {response_json}")

        # Check if access token is present in the response
        if 'access_token' not in response_json:
            raise Exception('Access token not found in the API response')

        # Log the access token scopes for debugging
        logger.info(f"Access Token Scopes: {response_json.get('scope')}")

        # Update refresh token in Secrets Manager if a new one is provided
        if 'refresh_token' in response_json:
            secrets['STRAVA_REFRESH_TOKEN'] = response_json['refresh_token']
            secrets_manager_client.update_secret(
                SecretId="StravaSecrets",
                SecretString=json.dumps(secrets)
            )
            logger.info('Updated refresh token in AWS Secrets Manager')

        return response_json['access_token']
    except RequestException as e:
        logger.error(f"Error fetching Strava access token: {e}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise

# Function to fetch Strava activities using the access token
def fetch_strava_activities(access_token):
    url = "https://www.strava.com/api/v3/athlete/activities"
    headers = {"Authorization": f"Bearer {access_token}"}

    logger.info(f"Headers: {headers}")

    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 429:
            retry_after = response.headers.get("Retry-After", 60)
            logger.error(f"Rate limit exceeded. Retry after {retry_after} seconds.")
            raise Exception("Rate limit exceeded.")
        response.raise_for_status()  # Raises an exception for 4XX/5XX responses
    except RequestException as e:
        logger.error(f"Error fetching Strava activities: {e}")
        raise

    return response.json()

# Lambda handler function
def lambda_handler(event, context):
    try:
        # Fetch new Strava access token
        access_token = fetch_strava_access_token()

        # Fetch activities from Strava API
        activities = fetch_strava_activities(access_token)

        # Convert activities to JSON string
        activities_str = json.dumps(activities)

        # Generate a dynamic S3 key based on the date and time
        key = f"activities_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.json"

        # Store the activities data in the specified S3 bucket
        s3_client.put_object(
            Bucket=os.environ['S3_BUCKET_NAME'],
            Key=key,
            Body=activities_str
        )

        logger.info(f"Successfully stored Strava activities in S3 with key: {key}")
        logger.info(f"Stored Activities: {activities_str}")

        return {
            'statusCode': 200,
            'body': json.dumps('Successfully retrieved and stored Strava activities.')
        }

    except Exception as e:
        logger.error(f"Error in Lambda function: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"Error occurred: {str(e)}")
        }
