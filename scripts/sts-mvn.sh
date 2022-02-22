#!/bin/sh
ROLE=$(aws configure get role_arn)
ROLE_SESSION_NAME=$(aws configure get role_session_name)
CRED=$(aws --output=json sts assume-role --role-arn $ROLE --role-session-name $ROLE_SESSION_NAME)

export AWS_ACCESS_KEY_ID=$(echo ${CRED} | jq -r ".Credentials.AccessKeyId")
export AWS_SECRET_ACCESS_KEY=$(echo ${CRED} | jq -r ".Credentials.SecretAccessKey")
export AWS_SESSION_TOKEN=$(echo ${CRED} | jq -r ".Credentials.SessionToken")

mvn $@