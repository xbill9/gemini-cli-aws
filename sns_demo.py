import boto3
import json
import time

# Region must match where you created your topic/queue
REGION = 'us-east-1'
TOPIC_ARN = 'arn:aws:sns:us-east-1:106059658660:xbill'
QUEUE_URL = 'https://sqs.us-east-1.amazonaws.com/106059658660/xbill'
QUEUE_ARN = 'arn:aws:sqs:us-east-1:106059658660:xbill'

# Create clients
sns = boto3.client('sns', region_name=REGION)
sqs = boto3.client('sqs', region_name=REGION)

def setup_subscription():
    """Subscribes SQS to SNS and adds permissions if necessary."""
    print(f"\nSubscribing SQS queue {QUEUE_ARN} to SNS topic {TOPIC_ARN}...")
    sns.subscribe(
        TopicArn=TOPIC_ARN,
        Protocol='sqs',
        Endpoint=QUEUE_ARN
    )
    
    # Add SQS policy to allow SNS to publish messages to it
    policy = {
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "sns.amazonaws.com"},
            "Action": "sqs:SendMessage",
            "Resource": QUEUE_ARN,
            "Condition": {"ArnEquals": {"aws:SourceArn": TOPIC_ARN}}
        }]
    }
    
    sqs.set_queue_attributes(
        QueueUrl=QUEUE_URL,
        Attributes={'Policy': json.dumps(policy)}
    )
    print("Subscription and permissions set up.")

def publish_to_sns(message):
    """'Writes' to SNS by publishing a message."""
    print(f"\nPublishing to SNS: {message}")
    response = sns.publish(
        TopicArn=TOPIC_ARN,
        Message=json.dumps(message),
        Subject="SNS Demo Message"
    )
    print(f"Message Published! Message ID: {response['MessageId']}")
    return response

def read_from_sqs():
    """'Reads' messages from SQS (delivered by SNS)."""
    print("\nReading messages from SQS (waiting up to 10 seconds)...")
    response = sqs.receive_message(
        QueueUrl=QUEUE_URL,
        MaxNumberOfMessages=5,
        WaitTimeSeconds=10
    )

    if 'Messages' in response:
        for msg in response['Messages']:
            # SNS messages sent to SQS are wrapped in an SNS JSON structure
            body = json.loads(msg['Body'])
            print(f"Received from SNS via SQS: {body['Message']}")
            
            # Delete message after processing
            sqs.delete_message(
                QueueUrl=QUEUE_URL,
                ReceiptHandle=msg['ReceiptHandle']
            )
            print("Message processed and deleted from queue.")
    else:
        print("No messages received.")

if __name__ == "__main__":
    # 1. Setup (run once)
    setup_subscription()
    
    # 2. Write (Publish to SNS)
    publish_to_sns({"event": "demo", "sender": "xbill-sns-script", "timestamp": time.time()})
    
    # 3. Read (Receive from SQS)
    # Give SNS a second to deliver to SQS
    time.sleep(2)
    read_from_sqs()
