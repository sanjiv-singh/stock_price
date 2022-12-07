#!/bin/bash


# Cleanup roles and policies
lambda_execution_policy_arn="arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
dynamodb_policy_arn="arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
kinesis_policy_arn="arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
sns_policy_arn="arn:aws:iam::aws:policy/AmazonSNSFullAccess"

aws iam detach-role-policy --role-name stockprice-kinesis-role --policy-arn $dynamodb_policy_arn
aws iam delete-role --role-name stockprice-kinesis-role
aws iam detach-role-policy --role-name stockprice-ec2-role --policy-arn $kinesis_policy_arn
aws iam delete-role --role-name stockprice-ec2-role
aws iam detach-role-policy --role-name stockprice-lambda-role --policy-arn $dynamodb_policy_arn
aws iam detach-role-policy --role-name stockprice-lambda-role --policy-arn $kinesis_policy_arn
aws iam detach-role-policy --role-name stockprice-lambda-role --policy-arn $sns_policy_arn
aws iam detach-role-policy --role-name stockprice-lambda-role --policy-arn $lambda_execution_policy_arn
aws iam delete-role --role-name stockprice-lambda-role

# Cleanup all ec2 instances
for id in $(aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId]" --output text);
do
  aws ec2 terminate-instances --instance-ids $id;
done
rm -f ip_address.txt
sleep 10

# Cleanup DynamoDB table
aws dynamodb delete-table --table-name stock-price-poi-alert

# Cleanup kinesis datastream
aws kinesis delete-stream --stream-name gl-stock-price --enforce-consumer-deletion


# Cleanup SNS
topic_arn=$(aws sns list-topics --output text | \
        grep stockprice-alert | awk -F ' ' '{print $2}')
subs_arn=$(aws sns list-subscriptions --query \
        "Subscriptions[?TopicArn=='$topic_arn' && \
        Protocol=='email'].SubscriptionArn" --output text)
aws sns unsubscribe --subscription-arn $subs_arn
aws sns delete-topic --topic-arn $topic_arn

# Cleanup Lambda Function
uuid=$(aws lambda list-event-source-mappings --query "EventSourceMappings[*].UUID" --output text)
aws lambda delete-event-source-mapping --uuid $uuid
aws lambda delete-function --function-name stock_poi_alerter
rm -f stock_poi_alerter.zip

# cleanup key pair and security groups
rm -f gl-test.pem
aws ec2 delete-key-pair --key-name gl-test
aws ec2 delete-security-group --group-name gl-sg

