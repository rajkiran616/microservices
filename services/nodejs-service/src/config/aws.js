const { SQSClient } = require('@aws-sdk/client-sqs');
const { S3Client } = require('@aws-sdk/client-s3');

const awsConfig = {
  region: process.env.AWS_REGION || 'us-east-1',
};

if (process.env.LOCALSTACK_ENDPOINT) {
  awsConfig.endpoint = process.env.LOCALSTACK_ENDPOINT;
  awsConfig.credentials = {
    accessKeyId: 'test',
    secretAccessKey: 'test'
  };
}

const sqsClient = new SQSClient(awsConfig);
const s3Client = new S3Client(awsConfig);

module.exports = {
  sqsClient,
  s3Client,
  queueUrl: process.env.SQS_QUEUE_URL,
  bucketName: process.env.S3_BUCKET_NAME
};
