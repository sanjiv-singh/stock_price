import boto3
import json
import base64
from boto3.dynamodb.conditions import Key
from datetime import datetime, timedelta
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
db_table = dynamodb.Table('stock-price-poi-alert')
sns_client = boto3.client('sns')
sns_topic_arn = "arn:aws:sns:us-east-1:279353633617:stockprice-alert"

def send_sns_notification(data):
    body = "\n".join([f'{k}:\t{v}' for k,v in data.items()])
    response = sns_client.publish(
        TargetArn=sns_topic_arn,
        Message=json.dumps({'default': body}),
        Subject=f'Stock Price Alert for {data["stockid"]}',
        MessageStructure='json')

def store_data(data):

    parsed_data = json.loads(json.dumps(data), parse_float=Decimal)
    response = db_table.put_item(
        Item=parsed_data
    )

def handle_poi(data):

    stockid = data["stockid"]
    timestamp = datetime.strptime(data["timestamp"], "%Y-%m-%d %H:%M:%S")
    present_date = timestamp.date()
    next_date = present_date + timedelta(days=1)
    start_time = datetime.strftime(present_date, "%Y-%m-%d %H:%M:%S")
    end_time = datetime.strftime(next_date, "%Y-%m-%d %H:%M:%S")

    query_params = {}
    query_params['KeyConditionExpression'] = Key('stockid').eq(stockid) & \
            Key('timestamp').between(start_time, end_time)
    response = db_table.query(**query_params)
    pois = response.get('Items')
    if pois:
        return None
    store_data(data)
    send_sns_notification(data)


def lambda_handler(event, context):
    records = event.get('Records')
    if not records:
        return {'status': 404}
    
    for record in records:
        data_str = base64.b64decode(record['kinesis']['data'])
        data = json.loads(data_str)
        high = float(data["52WeekHigh"])
        low = float(data["52WeekLow"])
        if float(data["price"]) >= 0.85 * high:
            handle_poi(data)
        if float(data["price"]) < 1.2 * low:
            handle_poi(data)

    return {'status': 200}
