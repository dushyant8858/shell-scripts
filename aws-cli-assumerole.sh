#! /bin/bash
#
# Dependencies:
#   brew install jq
#
# Setup:
#   chmod +x ./aws-cli-assumerole.sh
#
# Execute:
#   source ./aws-cli-assumerole.sh
#
# Description:
#   Makes assuming an AWS IAM role (+ exporting new temp keys) easier

# unset  AWS_SESSION_TOKEN
# export AWS_ACCESS_KEY_ID=<user_access_key>
# export AWS_SECRET_ACCESS_KEY=<user_secret_key>
# export AWS_REGION=eu-west-1


unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

aws sts get-caller-identity

Role_ARN_to_Assume=<IAM_Role_ARN>
temp_role=$(aws sts assume-role \
                    --role-arn $Role_ARN_to_Assume \
                    --role-session-name TestAssume)

export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq -r .Credentials.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq -r .Credentials.SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $temp_role | jq -r .Credentials.SessionToken)

aws sts get-caller-identity

