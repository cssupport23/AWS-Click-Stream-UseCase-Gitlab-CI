# AWS ClickStream UseCase with Gitlab CI
In this implementation, data flows from a **Kinesis Data Stream** to **Kinesis Firehose**, which delivers the data to an **S3 bucket**. The flow begins when a producer sends streaming events to the Kinesis Data Stream. Kinesis Firehose, configured as the delivery mechanism, collects these records and delivers them to the S3 bucket in JSON format. Firehose includes buffering options that control when and how the data is sent to S3, optimizing delivery based on size and time intervals.

Once the data lands in the S3 bucket, **Snowpipe** is automatically triggered using S3 event notifications. These events are routed through an **SQS queue**, which is consumed by Snowflake to process the data. Snowflake's **Snowpipe** utilizes an IAM user with programmatic access, specifically granted permission to access the required S3 resources. This IAM user's role is limited to actions like `s3:GetObject` and `s3:ListBucket` on the specific S3 path containing the data.

To ingest data into Snowflake, the `COPY INTO` statement with `MATCH_BY_COLUMN_NAME = 'CASE_INSENSITIVE'` ensures that the incoming JSON data's fields are correctly mapped to Snowflake table columns, even if there are case differences between the JSON keys and table column names. Additionally, `STRIP_OUTER_ARRAY` is used to handle potential arrays in the JSON, making sure the data is loaded correctly. This implementation avoids using an AWS Lambda function for JSON preprocessing, keeping the pipeline simpler and reducing compute costs.

Several AWS services are also integrated into this setup for observability and security:

1. **CloudWatch Logs**: CloudWatch collects logs from Kinesis Firehose for monitoring the delivery of data from Firehose to the S3 bucket. These logs provide visibility into the success or failure of records being delivered to S3 and enable troubleshooting if issues arise.

2. **CloudWatch Alarms**: A **CloudWatch Metric Alarm** is configured to monitor the success rate of Firehose's `PutRecord` operations. If the success rate falls below a certain threshold, an alarm is triggered, notifying stakeholders via an **SNS topic**. This ensures timely alerts for any delivery failures.

3. **CloudWatch Dashboards**: A CloudWatch Dashboard is used to visualize key metrics such as `PutRecord.Success` from Kinesis Firehose and logs from Snowpipe, giving a holistic view of the entire data ingestion process. This dashboard can display metrics like data delivery success, failure counts, and buffering behavior in Kinesis Firehose, providing valuable insights into system performance.

4. **IAM Role and Policy**: An **IAM Role** is created for Kinesis Firehose with the necessary permissions to deliver data to the S3 bucket. Additionally, an IAM policy for the **Snowpipe IAM User** ensures that the user has access to the S3 bucket but with restricted permissions, following the principle of least privilege.

This integrated setup leverages Kinesis Data Stream for real-time event ingestion, Kinesis Firehose for optimized delivery to S3, and Snowflake's Snowpipe for automatic ingestion into a database table. CloudWatch is used for monitoring, alerting, and logging to ensure operational health and visibility across the pipeline.

### S3 Bucket for Firehose Module

The `s3` module is responsible for creating the S3 bucket where the Kinesis Firehose stream will deliver data. This module abstracts the logic required to provision an S3 bucket with appropriate permissions and policies. It ensures that the bucket is configured to receive real-time streaming data from Firehose and makes use of the `s3_bucket_name` variable to name the bucket dynamically. The module also exposes the bucket’s ARN (`aws_s3_bucket_arn`), which is referenced by other modules like Kinesis and IAM to control access.

```hcl
module "s3" {
    source = "./modules/s3"
    s3_bucket_name = var.s3_bucket_name
}
```

### Kinesis Stream and Firehose Module

The `kinesis` module handles the creation of the Kinesis Stream and Kinesis Firehose. While Firehose is used to deliver data to S3, Kinesis Stream can be used for real-time data processing. The module takes several parameters, including the stream name, the Firehose delivery stream name, buffering settings (size and interval), and the S3 bucket ARN (from the `s3` module) where Firehose should send the data. This modular design allows easy scaling and flexibility in creating data streams and managing delivery configurations.

```hcl
module "kinesis" {
    source = "./modules/kinesis"
    stream_name = var.stream_name
    aws_s3_bucket_arn = module.s3.aws_s3_bucket_arn
    firehose_name = var.firehose_name
    buffering_size = var.buffering_size
    buffering_interval = var.buffering_interval
}
```

### IAM User for Snowflake Snowpipe Module

The `user` module provisions an IAM user that will be used by Snowflake's Snowpipe to access the S3 bucket and read the data for ingestion. The module grants the user the necessary S3 permissions, such as `GetObject` and `ListBucket`, for the specific bucket and prefix. The `s3_bucket_arn` and `s3_prefix` variables are passed to this module, ensuring that the IAM user has the correct level of access. This user is designed to have programmatic access only and no console access, making it secure for Snowpipe integration.

```hcl
module "user" {
    source = "./modules/user"
    s3_bucket_arn = module.s3.aws_s3_bucket_arn
    s3_prefix = var.s3_prefix
    user_name = var.user_name
}
```

### Kinesis Alarm and Dashboard Module

The `ops` module is responsible for operational monitoring, including setting up CloudWatch Alarms and Dashboards. It creates a CloudWatch alarm that monitors the Kinesis Firehose delivery stream’s success rate. The module uses the `clickstream_name` and `clickstream_firehose_name` to track the Kinesis Stream and Firehose activities. If the success rate falls below a defined threshold, an alarm triggers and sends an alert via SNS to the specified email. The module also provisions a CloudWatch Dashboard to provide real-time visibility into Kinesis Firehose and Stream operations, allowing operators to monitor the system's health.

```hcl
module "ops" {
    source = "./modules/ops"
    clickstream_name = var.stream_name
    clickstream_firehose_name = var.firehose_name
    sns_email = var.sns_email
    kinesis_producer_id = aws_instance.kinesis_producer.id
}
```

These modularized components ensure scalability and separation of concerns, making it easy to manage and update each aspect of the system independently, from S3 data storage to Kinesis streaming and Snowflake ingestion with Snowpipe.

### GitLab CI Integration

In this Terraform implementation, GitLab CI is leveraged for Continuous Integration (CI) and Continuous Deployment (CD). The pipeline employs a branching strategy that dynamically determines which variable file to use for each branch. The variable file (`$CI_COMMIT_REF_NAME.tfvars`) is passed to Terraform commands such as `terraform plan` and `terraform apply`, allowing different branches to manage separate sets of infrastructure configurations.

Each pipeline stage (validate, plan, apply, and destroy) uses the appropriate variable file, ensuring environment-specific parameters are applied based on the branch name. Additionally, S3 bucket and folder configurations for Terraform backend state storage are fetched dynamically from AWS SSM using environment variables (`S3_BUCKET_SSM` and `S3_FOLDER_SSM`). The pipeline’s caching policy ensures efficient use of Terraform state files and modules across different CI/CD jobs, making it highly reusable and scalable for managing infrastructure.

### GitLab CI Pipeline Stages

The GitLab CI pipeline for this Terraform infrastructure consists of the following stages:

1. **Before Script**:
   - **Initial Setup**: Several dependencies (`bash`, `parallel`, and `aws-cli`) are installed.
   - **Backend Configuration**: The Terraform backend is dynamically initialized by retrieving the S3 bucket and folder names from AWS SSM. This ensures the state files are stored in the correct S3 bucket based on the environment (`dev`, `staging`, `prod`) derived from the branch. This can be part of the custom image as well.

2. **Validate Stage**:
   - **Validation Check**: This stage ensures that the Terraform configuration files are syntactically correct and can be applied. It uses the branch-specific variable file, checking the correctness of the infrastructure code (`terraform validate`).
   - **Branch-Specific Variables**: The variable file is dynamically determined by the branch name (`$CI_COMMIT_REF_NAME.tfvars`), allowing validation against environment-specific configurations.

3. **Plan Stage**:
   - **Planning**: In this stage, Terraform creates an execution plan (`plan.out`) by comparing the current state of the infrastructure with the desired state. The plan details the changes Terraform would make to bring the infrastructure in line with the configuration in the `.tfvars` file for the current branch.
   - **Artifacts**: The execution plan is stored as an artifact and retained for 30 days, allowing it to be applied or reviewed later.

4. **Apply Stage**:
   - **Deployment**: If the `plan.out` file is approved manually, Terraform applies the changes described in the plan to the infrastructure (`terraform apply`). This ensures that the infrastructure is updated to match the desired state, as specified in the branch-specific `.tfvars` file.

5. **Destroy Stage**:
   - **Tear Down**: In this manual stage, Terraform destroys all resources specified in the variable file (`terraform destroy`). This stage is used when you want to clean up the infrastructure for a particular environment or branch.

The GitLab pipeline’s dynamic nature, combined with the use of SSM for backend configuration and branch-specific `.tfvars` files, ensures the infrastructure can be validated, deployed, and destroyed efficiently across different environments, all from a single pipeline.
