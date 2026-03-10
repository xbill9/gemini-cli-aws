import boto3
import json
import time

# Create SQS client
sqs = boto3.client('sqs', region_name='us-east-1')

# Get the queue URL
queue_name = 'xbill'
try:
    response = sqs.get_queue_url(QueueName=queue_name)
    queue_url = response['QueueUrl']
    print(f"Queue URL: {queue_url}")
except sqs.exceptions.QueueDoesNotExist:
    print(f"Error: Queue '{queue_name}' does not exist.")
    exit(1)

def send_message(body):
    """Sends a message to the SQS queue."""
    print(f"\nSending message: {body}")
    response = sqs.send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps(body)
    )
    print(f"Message ID: {response['MessageId']}")
    return response

def receive_messages():
    """Receives and deletes messages from the SQS queue."""
    print("\nReceiving messages...")
    response = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=10,
        WaitTimeSeconds=5
    )

    if 'Messages' in response:
        for message in response['Messages']:
            print(f"Received: {message['Body']}")
            
            # Delete message after processing
            sqs.delete_message(
                QueueUrl=queue_url,
                ReceiptHandle=message['ReceiptHandle']
            )
            print("Message deleted.")
    else:
        print("No messages found.")

if __name__ == "__main__":
    # Send sample messages
    send_message({"event": "hello", "timestamp": time.time(), "user": "xbill"})
    send_message({"event": "update", "timestamp": time.time(), "data": "SQS is working!"})

    # Wait a moment for messages to be available (though SQS is usually instant)
    time.sleep(2)

    # Receive and process messages
    receive_messages()
