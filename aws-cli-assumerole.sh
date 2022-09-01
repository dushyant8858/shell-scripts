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



# -------------- 2 --------------

~$ aws sts get-caller-identity
```
{
    "UserId": "xxx:i-node",
    "Account": "xxx",
    "Arn": "arn:aws:sts::xxx:assumed-role/node-role/i-node"
}
```

# •	Assume the ClusterCreator role
CREDS=$(aws sts assume-role \
--role-arn arn:aws:iam::xxx:role/cluster-creator-role  \
--role-session-name $(date '+%Y%m%d%H%M%S%3N') \
--duration-seconds 3600 \
--query '[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]' \
--output text)
export AWS_DEFAULT_REGION="us-west-2"
export AWS_ACCESS_KEY_ID=$(echo $CREDS | cut -d' ' -f1)
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | cut -d' ' -f2)
export AWS_SESSION_TOKEN=$(echo $CREDS | cut -d' ' -f3)


# •	For the assume role to succeed, the `node-role` role should be allowed to assume `cluster-creator-role` role through IAM permissions. Here is the permission set for `node-role` that allows assume role:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": [
                "arn:aws:iam::xxx:role/cluster-creator-role",
            ]
        }
    ]
}
```
# •	For the assume role to succeed, `cluster-creator-role` role should have trust relationship with `node-role`. Here is the Trust permission for the `cluster-creator-role`:
```
{
    "Effect": "Allow",
    "Principal": {
        "AWS": "arn:aws:iam::xxx:role/node-role"
    },
    "Action": "sts:AssumeRole"
}
 ```
~$ aws sts get-caller-identity
```
{
    "UserId": "xxx:20220901000909066",
    "Account": "xxx",
    "Arn": "arn:aws:sts::xxx:assumed-role/cluster-creator-role/20220901000909066"
}
```

# -------------------------------
