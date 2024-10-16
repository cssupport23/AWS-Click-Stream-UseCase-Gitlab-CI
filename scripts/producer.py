import json
import random
import time
import boto3
from datetime import datetime

# Initialize boto3 client for Kinesis
kinesis_client = boto3.client('kinesis', region_name='ap-south-1')

STREAM_NAME = 'clickstream_test'

def get_random_event():
    user_id = f"user_{random.randint(1, 100)}"
    session_id = f"session_{random.randint(1, 1000)}"
    page_id = f"page_{random.randint(1, 20)}"
    timestamp = datetime.utcnow().isoformat()
    event_type = random.choice(['page_view', 'scroll', 'session_end'])
    
    event = {
        "user_id": user_id,
        "session_id": session_id,
        "page_id": page_id,
        "timestamp": timestamp,
        "event_type": event_type,
        "platform": random.choice(['web', 'mobile'])
    }
    
    if event_type == 'scroll':
        event["scroll_depth"] = random.randint(1, 100)
    elif event_type == 'session_end':
        event["session_duration"] = random.randint(60, 600)
    
    return json.dumps(event)

def send_to_kinesis(event):
    kinesis_client.put_record(
        StreamName=STREAM_NAME,
        Data=event,
        PartitionKey='partition_key'
    )

if __name__ == "__main__":
    count = 0
    while True:
        if count == 100:
            break;
        event = get_random_event()
        print(f"Sending event: {event}")
        send_to_kinesis(event)
        time.sleep(1)
        count = count + 1
