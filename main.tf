
# S3 bucket for Firehose
module "s3" {
    source = "./modules/s3"
    s3_bucket_name = var.s3_bucket_name
}

# Kinesis Stream and Firehose
module "kinesis" {
    source = "./modules/kinesis"
    stream_name = var.stream_name
    aws_s3_bucket_arn = module.s3.aws_s3_bucket_arn
    firehose_name = var.firehose_name
    buffering_size = var.buffering_size
    buffering_interval = var.buffering_interval

}
#IAM User For Snowflake Snowpipe
module "user" {
    source = "./modules/user"
    s3_bucket_arn = module.s3.aws_s3_bucket_arn
    s3_prefix = var.s3_prefix
    user_name = var.user_name
}

# Kinesis Alarm and Dashboard
module "ops" {
    source = "./modules/ops"
    clickstream_name = var.stream_name
    clickstream_firehose_name = var.firehose_name
    sns_email = var.sns_email
    kinesis_producer_id = aws_instance.kinesis_producer.id
}

# EC2 instnace for exmaple producer
resource "aws_instance" "kinesis_producer" {
    ami           = var.ami  # Replace with your desired AMI
    instance_type = var.instance_type
    vpc_security_group_ids = [aws_security_group.kinesis_producer_sg.id]
    
    # Create EC2 instance and attach IAM role for Kinesis
    iam_instance_profile = aws_iam_instance_profile.kinesis_producer_profile.name
  
    user_data = <<-EOF
                #!/bin/bash
                yum update -y
                yum install python3-pip -y
                pip3 install boto3
                cat << 'EOPY' > /home/ec2-user/producer.py
                ${templatefile("${path.module}/scripts/producer.py", {})}
                EOPY
                nohup python3 /home/ec2-user/producer.py &
                EOF
    
    tags = {
        Name = "KinesisDataProducer"
    }
}

  
  resource "aws_iam_role" "kinesis_producer_role" {
    name = "kinesis_producer_role"
  
    assume_role_policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [{
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }]
    })
  }
  
  resource "aws_iam_role_policy" "kinesis_producer_policy" {
    role = aws_iam_role.kinesis_producer_role.name
  
    policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": [
            "kinesis:PutRecord"
          ],
          "Effect": "Allow",
          "Resource": "*"
        }
      ]
    })
  }
  
  resource "aws_iam_instance_profile" "kinesis_producer_profile" {
    name = "kinesis_producer_profile"
    role = aws_iam_role.kinesis_producer_role.name
  }
  
  resource "aws_security_group" "kinesis_producer_sg" {
    name        = "kinesis_producer_sg"
    description = "Security group for Kinesis producer EC2 instance"
    vpc_id      = data.aws_ssm_parameter.vpc_id.value  # Replace with your VPC ID
  
    # Allow SSH access (port 22) from your IP (replace with your actual IP)
    ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]  # Replace with your public IP address
    }
  
    # Allow outbound traffic to Kinesis
    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"  # Allow all protocols
      cidr_blocks = ["0.0.0.0/0"]  # Allows outbound access to all destinations
    }
  
    tags = {
      Name = "kinesis_producer_sg"
    }
  }

  # Loggroup for producer
  resource "aws_cloudwatch_log_group" "ec2_log_group" {
    name = "/ec2/kinesis_producer_logs"
    retention_in_days = 7
  }
  
  resource "aws_iam_role_policy" "cloudwatch_logs_policy" {
    role = aws_iam_role.kinesis_producer_role.id
  
    policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource": "*"
        }
      ]
    })
  }
  
  