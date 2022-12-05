#!/bin/bash


create_key_pair () {
    # create a fresh key pair
    aws ec2 create-key-pair --key-name gl-test --query 'KeyMaterial' | sed -e 's/"//g' -e 's/\\n/\n/g' > gl-test.pem
    chmod 400 gl-test.pem
}

my_ip=$(curl https://checkip.amazonaws.com)


create_security_group () {
    # create a fresh security group and open ssh port from MyIp
    aws ec2 create-security-group --group-name gl-sg --description "Security group for gl devbox"
    aws ec2 authorize-security-group-ingress --group-name gl-sg --protocol tcp --port 22 --cidr $my_ip/32
}

create_ec2_instance () {
    # Create a new ec2 instance
    instance_id=$(aws ec2 run-instances --image-id ami-0b0dcb5067f052a63 --instance-type t2.micro --key-name gl-test --security-groups gl-sg --query 'Instances[*].[InstanceId]' --output text)
}

prepare_instance () {
    # Grant IAM role to access kinesis datastream
    kinesis_policy_arn="arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
    aws iam create-role --role-name stockprice-ec2-role --assume-role-policy-document file://ec2_policy.json --output text
    aws iam attach-role-policy --role-name stockprice-ec2-role --policy-arn $kinesis_policy_arn

    # Obtain the public IP addr of the new instance
    ip_address=$(aws ec2 describe-instances --filter "Name=instance-id,Values=$instance_id" --query 'Reservations[*].Instances[*].[PublicIpAddress]' --output text)
    echo $ip_address > ip_address.txt
    sleep 30
    # Prepare the instance
    ssh -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ec2-user@$ip_address "sudo yum update -y"
    ssh -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ec2-user@$ip_address "sudo yum install python3 -y"
    ssh -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ec2-user@$ip_address "sudo pip3 install --upgrade pip"
    ssh -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ec2-user@$ip_address "sudo pip3 install yfinance boto3"
    scp -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null *.py ec2-user@$ip_address:.
    ssh -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ec2-user@$ip_address "aws configure --profile default"
}

create_datastream () {
    # Create a Kinesis Datastream
    aws kinesis create-stream --stream-name gl-stock-price --shard-count 1 --stream-mode-details "StreamMode=PROVISIONED"
}

prepare_datastream () {
    stream_arn=$(aws kinesis describe-stream --stream-name gl-stock-price --query "StreamDescription.StreamARN")
    echo $stream_arn
    dynamodb_policy_arn="arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
    aws iam create-role --role-name stockprice-kinesis-role --assume-role-policy-document file://kinesis_policy.json --output text
    aws iam attach-role-policy --role-name stockprice-kinesis-role --policy-arn $dynamodb_policy_arn
}

create_table () {
    aws dynamodb create-table --table-name stock-price-poi-alert \
        --attribute-definitions AttributeName=stockid,AttributeType=S \
            AttributeName=timestamp,AttributeType=S \
        --key-schema AttributeName=stockid,KeyType=HASH \
            AttributeName=timestamp,KeyType=RANGE \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
}

create_lambda () {
    dynamodb_policy_arn="arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
    kinesis_policy_arn="arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
    sns_policy_arn="arn:aws:iam::aws:policy/AmazonSNSFullAccess"
    aws iam create-role --role-name stockprice-lambda-role \
        --assume-role-policy-document file://lambda_policy.json --output text
    aws iam attach-role-policy --role-name stockprice-lambda-role \
        --policy-arn $dynamodb_policy_arn
    aws iam attach-role-policy --role-name stockprice-lambda-role \
        --policy-arn $kinesis_policy_arn
    aws iam attach-role-policy --role-name stockprice-lambda-role \
        --policy-arn $sns_policy_arn
    role_arn=$(aws iam get-role --role-name "stockprice-lambda-role" \
        --query "Role.Arn" --output text)
    sleep 5

    aws lambda create-function \
        --function-name stock-poi-alerter \
        --runtime python3.8 \
        --zip-file fileb://stock-poi-alerter.zip \
        --handler stock-poi-alerter.lambda_handler \
        --role $role_arn

    sleep 5
    stream_arn=$(aws kinesis describe-stream --stream-name gl-stock-price \
        --query "StreamDescription.StreamARN" --output text)
    aws lambda create-event-source-mapping --function-name stock-poi-alerter \
        --batch-size 500 --starting-position LATEST \
        --event-source-arn $stream_arn
}

create_sns () {
topic_arn=$(aws sns create-topic --name stockprice-alert \
        --query "TopicArn" --output text)
aws sns subscribe --topic-arn $topic_arn --protocol email \
        --notification-endpoint sk.sanjiv@gmail.com
echo "A notification has been sent to $subscription_email. Please confirm subscription before resuming."
}

echo "Creating key pair gl-test"
create_key_pair
sleep 5
echo "Creating security group and granting ssh access from $my_ip"
create_security_group
echo "Creating kinesis datastream"
create_datastream
sleep 5
echo "Preparing kinesis datastream"
prepare_datastream
echo "Creating dynamodb table"
create_table
echo "Creating lambda function"
create_lambda
echo "Creating SNS topic and subscription"
create_sns
echo "Creating ec2 instance"
create_ec2_instance
sleep 30
echo "Preparing ec2 instance"
prepare_instance

