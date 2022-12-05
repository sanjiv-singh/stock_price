#!/bin/bash


# Obtain IP Addr
ip_address=$(cat ip_address.txt)

# Copy the application to ec2 instance
scp -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null *.py ec2-user@$ip_address:.

# Run the application in ec2 instance
ssh -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ec2-user@$ip_address "python3 stock_price_ingestion.py"
