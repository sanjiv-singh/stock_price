import json
import boto3
import sys
import yfinance as yf

import time
import random
import datetime

TICKERS = ['MSFT', 'MVIS', 'GOOG', 'SPOT', 'INO', 'OCGN', 'ABML', 'RLLCF', 'JNJ', 'PSFE']

# Your goal is to get per-hour stock price data for a time range for the ten stocks specified in the doc. 
# Further, you should call the static info api for the stocks to get their current 52WeekHigh and 52WeekLow values.
# You should craft individual data records with information about the stockid, price, price timestamp,
# 52WeekHigh and 52WeekLow values and push them individually on the Kinesis stream

kinesis = boto3.client('kinesis', region_name = "us-east-1") #Modify this line of code according to your requirement.

today = datetime.date.today() - datetime.timedelta(days=2)
day_of_week = today.weekday()
if day_of_week < 2:
    today += datetime.timedelta(2 - day_of_week)
yesterday = today - datetime.timedelta(1)

# Example of pulling the data between 2 dates from yfinance API
#data = yf.download("MSFT", start=yesterday, end=today, interval='1h' )

# Add code to pull the data for the stocks specified in the doc
stock_data = {}
for ticker in TICKERS:
    data = yf.download(ticker, start=yesterday, end=today, interval='1h' )
    stock_data[ticker] = data

for ticker, data in stock_data.items():
    print(f"------------------- {ticker} ----------------")
    print(data.head())
# Add additional code to call 'info' API to get 52WeekHigh and 52WeekLow refering this this link - https://pypi.org/project/yfinance/


## Add your code here to push data records to Kinesis stream.


