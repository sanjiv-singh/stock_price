#!/bin/bash


# Cleanup roles and policies
dynamodb_policy_arn="arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
aws iam detach-role-policy --role-name stockprice-kinesis-role --policy-arn $dynamodb_policy_arn
aws iam delete-role --role-name stockprice-kinesis-role
kinesis_policy_arn="arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
aws iam detach-role-policy --role-name stockprice-ec2-role --policy-arn $kinesis_policy_arn
aws iam delete-role --role-name stockprice-ec2-role

# Cleanup kinesis datastream
aws kinesis delete-stream --stream-name gl-stock-price --enforce-consumer-deletion

# Cleanup all ec2 instances
for id in $(aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId]" --output text);
do
  aws ec2 terminate-instances --instance-ids $id;
done

# cleanup key pair and security groups
rm -f gl-test.pem
aws ec2 delete-key-pair --key-name gl-test
aws ec2 delete-security-group --group-name gl-sg

