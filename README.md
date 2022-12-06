# stock_price_ingestion
Cloud Processing of Yahoo Finance Data

This project has been completed as part of course on Software Engineering for IoT, Blockchain and Cloud Computing conducted by Great Learning&reg; in collaboration with IIT, Madras

##  Project Destription

The project uses bash scripts to create the required cloud infrastructure on AWS using aws cli. The `setup.sh` script sets up the ec2 instances, kinesis datastream, lambda function, sns topic & subscription and dynamodb table. The `cleanup.sh` may be used to cleanup the resources on the cloud. The `run.sh` script is used to run the application on the ec2 instance. It uses ssh to run the application remotely on the ec2 instance.

The main application comprises two python files. `stock_price_ingestion.py` is the main script. It uses the `KinesisDatastream` class defined in the `stream.py` module.

The lambda function is defined in `stock_poi_alerter.py` file. It detects pois based on the given condition (>=85% of 52WeekHigh or <= 120% of 52WeekLow). In case the poi is the first for the day an email alert is sent through SNS and the data is also stored in a dynamodb table.

## Setting up the cloud infrastructure

The provided script runs on Linux (Unix) and Mac platforms systems only. It is assumed that aws cli is installed on the system and properly configured with access key and secret.

```console
foo@bar:~$ cd <project dir>
foo@bar:~$ chmod 755 setup.sh
foo@bar:~$ ./setup.sh
```

The script also sets up the ec2 instance with aws cli and prompts for access key and secret for the ec2 instance. 

## Running the program

```console
foo@bar:~$ chmod 755 run.sh
foo@bar:~$ ./run.sh
```

## Cleaning up resources on cloud

```console
foo@bar:~$ chmod 755 cleanup.sh
foo@bar:~$ ./cleanup.sh
```


&copy; Great Learning&reg; and IIT, Madras

