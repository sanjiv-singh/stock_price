#!/bin/bash


create_key_pair () {
    # Remove and create a fresh key pair
    rm -f gl-test.pem
    aws ec2 delete-key-pair --key-name gl-test
    aws ec2 create-key-pair --key-name gl-test --query 'KeyMaterial' | sed -e 's/"//g' -e 's/\\n/\n/g' > gl-test.pem
    chmod 400 gl-test.pem
}


create_security_group () {
    # Remove and create a fresh security group and open ssh port from MyIp
    aws ec2 delete-security-group --group-name gl-sg
    aws ec2 create-security-group --group-name gl-sg --description "Security group for gl devbox"
    aws ec2 authorize-security-group-ingress --group-name gl-sg --protocol tcp --port 22 --cidr `curl https://checkip.amazonaws.com`/32
}

create_ec2_instance () {
    # Create a new ec2 instance
    instance_id=$(aws ec2 run-instances --image-id ami-0b0dcb5067f052a63 --instance-type t2.micro --key-name gl-test --security-groups gl-sg --query 'Instances[*].[InstanceId]' --output text)
}

prepare_instance () {
    # Grant IAM role to access kinesis datastream
    kinesis_policy_arn="arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
    aws iam detach-role-policy --role-name stockprice-ec2-role --policy-arn $kinesis_policy_arn
    aws iam delete-role --role-name stockprice-ec2-role
    aws iam create-role --role-name stockprice-ec2-role --assume-role-policy-document file://ec2_policy.json --output text
    aws iam attach-role-policy --role-name stockprice-ec2-role --policy-arn $kinesis_policy_arn

    # Obtain the public IP addr of the new instance
    ip_address=$(aws ec2 describe-instances --filter "Name=instance-id,Values=$instance_id" --query 'Reservations[*].Instances[*].[PublicIpAddress]' --output text)
    echo $ip_aadress > ip_address.txt
    sleep 30
    # Prepare the instance
    ssh -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ec2-user@$ip_address "sudo yum update -y"
    ssh -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ec2-user@$ip_address "sudo yum install python3 -y"
    ssh -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ec2-user@$ip_address "sudo pip3 install --upgrade pip"
    ssh -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ec2-user@$ip_address "sudo pip3 install yfinance boto3"
    scp -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null stock_price_ingestion.py ec2-user@$ip_address:.
}

create_datastream () {
    # Create a Kinesis Datastream
    aws kinesis delete-stream --stream-name gl-stock-price --enforce-consumer-deletion
    sleep 5
    aws kinesis create-stream --stream-name gl-stock-price --shard-count 1 --stream-mode-details "StreamMode=PROVISIONED"
}

prepare_datastream () {
    stream_arn=$(aws kinesis describe-stream --stream-name gl-stock-price --query "StreamDescription.StreamARN")
    echo $stream_arn
    dynamodb_policy_arn="arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
    aws iam detach-role-policy --role-name stockprice-kinesis-role --policy-arn $dynamodb_policy_arn
    aws iam delete-role --role-name stockprice-kinesis-role
    aws iam create-role --role-name stockprice-kinesis-role --assume-role-policy-document file://kinesis_policy.json --output text
    aws iam attach-role-policy --role-name stockprice-kinesis-role --policy-arn $dynamodb_policy_arn
}

create_key_pair
sleep 5
create_security_group
sleep 5
create_ec2_instance
sleep 30
prepare_instance
create_datastream
sleep 5
prepare_datastream

