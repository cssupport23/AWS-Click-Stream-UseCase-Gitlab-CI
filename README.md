# AWS ClickStream UseCase with Gitlab CI
In this implementation, data flows from a Kinesis Firehose stream into an S3 bucket, and from there, it is ingested into Snowflake using Snowpipe for real-time data processing. The workflow starts with Kinesis Firehose, which is responsible for handling large-scale streaming data by buffering and delivering it to the specified S3 bucket. This eliminates the need for manually managing Kinesis Data Streams, as Firehose handles both delivery and transformation. 

To ensure secure access to the data, an IAM user is configured with permissions to interact with the S3 bucket. This IAM user is used by Snowpipe to trigger an event-driven data ingestion process as soon as new data is written to the S3 bucket. Additionally,  CloudWatch Alarms are set up to monitor the health and success of the data ingestion process. The alarms monitor metrics such as the success rate of Firehose put records. If failures or performance degradation occur, the CloudWatch Alarm sends a notification through an SNS topic to alert relevant stakeholders.

A CloudWatch Dashboard is configured to visualize important metrics such as Kinesis Firehose success rates.

Finally, Snowpipe is configured to use the `COPY INTO` command, which automatically ingests data from the S3 bucket into a Snowflake table. The `MATCH_BY_COLUMN_NAME` option ensures that the incoming JSON data matches the table's schema, even if there are case discrepancies. Additionally, the `STRIP_OUTER_ARRAY` file format option ensures proper handling of the JSON data, avoiding issues with nested structures and null values.

All the resouces are split into modules.

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
