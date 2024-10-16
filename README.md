# AWS_Click_Stream_UseCase
In this implementation, data flows from a Kinesis Firehose stream into an S3 bucket, and from there, it is ingested into Snowflake using Snowpipe for real-time data processing. The workflow starts with Kinesis Firehose, which is responsible for handling large-scale streaming data by buffering and delivering it to the specified S3 bucket. This eliminates the need for manually managing Kinesis Data Streams, as Firehose handles both delivery and transformation. 

To ensure secure access to the data, an IAM user is configured with permissions to interact with the S3 bucket. This IAM user is used by Snowpipe to trigger an event-driven data ingestion process as soon as new data is written to the S3 bucket. Additionally,  CloudWatch Alarms are set up to monitor the health and success of the data ingestion process. The alarms monitor metrics such as the success rate of Firehose put records. If failures or performance degradation occur, the CloudWatch Alarm sends a notification through an SNS topic to alert relevant stakeholders.

A CloudWatch Dashboard is configured to visualize important metrics such as Kinesis Firehose success rates.

Finally, Snowpipe is configured to use the `COPY INTO` command, which automatically ingests data from the S3 bucket into a Snowflake table. The `MATCH_BY_COLUMN_NAME` option ensures that the incoming JSON data matches the table's schema, even if there are case discrepancies. Additionally, the `STRIP_OUTER_ARRAY` file format option ensures proper handling of the JSON data, avoiding issues with nested structures and null values.

