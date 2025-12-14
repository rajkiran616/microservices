const { ReceiveMessageCommand, DeleteMessageCommand } = require('@aws-sdk/client-sqs');
const { sqsClient, queueUrl } = require('../config/aws');

let isPolling = false;

const processMessage = async (message) => {
  try {
    const body = JSON.parse(message.Body);
    console.log('Processing SQS message:', body);
    
    // Process order notifications
    if (body.subject === 'ORDER_CREATED' || body.subject === 'ORDER_STATUS_UPDATED') {
      console.log(`Order notification received: ${body.message}`);
      // Add business logic here (e.g., send email, update user stats)
    }
  } catch (error) {
    console.error('Error processing message:', error);
  }
};

const pollMessages = async () => {
  if (!isPolling || !queueUrl) return;

  try {
    const command = new ReceiveMessageCommand({
      QueueUrl: queueUrl,
      MaxNumberOfMessages: 10,
      WaitTimeSeconds: 20,
      VisibilityTimeout: 30
    });

    const response = await sqsClient.send(command);

    if (response.Messages) {
      for (const message of response.Messages) {
        await processMessage(message);
        
        // Delete message after processing
        await sqsClient.send(new DeleteMessageCommand({
          QueueUrl: queueUrl,
          ReceiptHandle: message.ReceiptHandle
        }));
      }
    }
  } catch (error) {
    console.error('Error polling SQS:', error);
  }

  // Continue polling
  if (isPolling) {
    setImmediate(pollMessages);
  }
};

module.exports = {
  startPolling: () => {
    if (!queueUrl) {
      console.log('SQS queue URL not configured, skipping consumer');
      return;
    }
    isPolling = true;
    pollMessages();
  },
  stopPolling: () => {
    isPolling = false;
  }
};
