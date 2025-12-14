#!/bin/bash

echo "Initializing LocalStack resources..."

# Create S3 buckets
awslocal s3 mb s3://orders-bucket
awslocal s3 mb s3://users-bucket

# Create SNS topic
awslocal sns create-topic --name order-events

# Create SQS queue
awslocal sqs create-queue --queue-name order-notifications

# Subscribe SQS queue to SNS topic
TOPIC_ARN="arn:aws:sns:us-east-1:000000000000:order-events"
QUEUE_URL="http://localstack:4566/000000000000/order-notifications"
QUEUE_ARN="arn:aws:sqs:us-east-1:000000000000:order-notifications"

awslocal sns subscribe \
    --topic-arn $TOPIC_ARN \
    --protocol sqs \
    --notification-endpoint $QUEUE_ARN

echo "LocalStack resources initialized successfully!"
