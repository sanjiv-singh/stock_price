import boto3
import yfinance as yf
from datetime import date, datetime, timedelta
from stream import KinesisStream

TICKERS = ['MSFT', 'MVIS', 'GOOG', 'SPOT', 'INO', 'OCGN', 'ABML', 'RLLCF', 'JNJ', 'PSFE']

# Your goal is to get per-hour stock price data for a time range for the ten stocks specified in the doc. 
# Further, you should call the static info api for the stocks to get their current 52WeekHigh and 52WeekLow values.
# You should craft individual data records with information about the stockid, price, price timestamp,
# 52WeekHigh and 52WeekLow values and push them individually on the Kinesis stream

kinesis = boto3.client('kinesis', region_name = "us-east-1") #Modify this line of code according to your requirement.

today = date.today() - timedelta(days=2)
day_of_week = today.weekday()
if day_of_week < 2:
    today += timedelta(2 - day_of_week)
yesterday = today - timedelta(1)

# Example of pulling the data between 2 dates from yfinance API
#data = yf.download("MSFT", start=yesterday, end=today, interval='1h' )


def get_hourly_stock_data(stockid, high, low):
    hourly_stock_data = []
    data = yf.download(stockid, start=yesterday, end=today, interval='1h')
    for timestamp in data.index:
        hourly_data = {}
        _data = data.loc[timestamp]
        hourly_data['stockid'] = stockid
        hourly_data['price'] = _data['Close']
        hourly_data['timestamp'] = datetime.strftime(timestamp, "%Y-%m-%d %H:%M:%S")
        hourly_data['52WeekHigh'] = high
        hourly_data['52WeekLow'] = low
        hourly_stock_data.append(hourly_data)
    return hourly_stock_data

# Add code to pull the data for the stocks specified in the doc
# Add additional code to call 'info' API to get 52WeekHigh and 52WeekLow refering this this link - https://pypi.org/project/yfinance/
stock_data = []
for ticker in TICKERS:
    _t = yf.Ticker(ticker)
    high = _t.info.get('fiftyTwoWeekHigh')
    low = _t.info.get('fiftyTwoWeekLow')
    stock_data.extend(get_hourly_stock_data(ticker, high, low))

print('\n----------------------- Stock Data --------------------')
print('STOCK:\tTIMESTAMP\t\tSTOCK PRICE\t52WEEKHIGH\t52WEEKLOW')
sorted_stock_data = sorted(stock_data, key=lambda d: d['timestamp']) 

for data in sorted_stock_data:
    print(f'{data["stockid"]}\t{data["timestamp"]}\t{data["price"]}\t{data["52WeekHigh"]}\t{data["52WeekLow"]}')


## Add your code here to push data records to Kinesis stream.
stream = KinesisStream(kinesis, 'gl-stock-price')
for data in sorted_stock_data:
    stream.put_record(data, "stockid")


