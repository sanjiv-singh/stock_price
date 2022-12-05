import boto3
import json
import base64
import logging
from decimal import Decimal

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
db_table = dynamodb.Table('stock-price-poi-alert')
sns_client = boto3.client('sns')
sns_topic_arn = "arn:aws:sns:us-east-1:012345627499:Stock_Price_Alert_Notification"

def send_sns_notification(data):
    response = sns_client.publish(
        TargetArn=sns_topic_arn,
        Message=json.dumps({'default': json.dumps(data)}),
        Subject=f'Stock Price Alert for {data["stockid"]}',
        MessageStructure='json')

def handle_poi(data):
    parsed_data = json.loads(data, parse_float=Decimal)
    response = db_table.put_item(
        Item=parsed_data
    )
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
            handle_poi(json.dumps(data))

    return {'status': 200}