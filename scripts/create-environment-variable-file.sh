#!/bin/sh
ROLE=$(aws configure get role_arn)
ROLE_SESSION_NAME=$(aws configure get role_session_name)
CRED=$(aws --output=json sts assume-role --role-arn $ROLE --role-session-name $ROLE_SESSION_NAME)

AWS_ACCESS_KEY_ID=$(echo ${CRED} | jq -r ".Credentials.AccessKeyId")
AWS_SECRET_ACCESS_KEY=$(echo ${CRED} | jq -r ".Credentials.SecretAccessKey")
AWS_SESSION_TOKEN=$(echo ${CRED} | jq -r ".Credentials.SessionToken")
AWS_REGION="eu-west-1"

echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" > .env
echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> .env
echo "AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN" >> .env
echo "AWS_REGION=$AWS_REGION" >> .env