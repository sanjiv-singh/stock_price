#!/bin/bash


# Obtain IP Addr
ip_address=$(cat ip_address.txt)

# Run the application in the ec2 instance
ssh -i gl-test.pem -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null ec2-user@$ip_address "python3 stock_price_ingestion.py"
