resource "aws_kinesis_stream" "clickstream" {
    name             = var.stream_name
    shard_count      = var.shard_count
    retention_period = var.retention_period  # Data retention in hours
  }
  
  resource "aws_iam_role" "firehose_delivery_role" {
    name = "firehose_delivery_role"
  
    assume_role_policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "firehose.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    })
  }

  resource "aws_iam_role_policy" "firehose_delivery_policy" {
    role = aws_iam_role.firehose_delivery_role.id
  
    policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "kinesis:GetShardIterator",
            "kinesis:GetRecords",
            "kinesis:DescribeStream",
            "kinesis:ListStreams"
          ],
          "Resource": aws_kinesis_stream.clickstream.arn
        },
        {
          "Effect": "Allow",
          "Action": [
            "s3:PutObject",
            "s3:PutObjectAcl",
            "s3:ListBucket"
          ],
          "Resource": [
            var.aws_s3_bucket_arn,
            "${var.aws_s3_bucket_arn}/*"
          ]
        },
        {
          "Effect": "Allow",
          "Action": [
            "logs:PutLogEvents"
          ],
          "Resource": "*"
        }
      ]
    })
  }
  

    resource "aws_kinesis_firehose_delivery_stream" "clickstream_firehose" {
    name        = var.firehose_name
    destination = "extended_s3"
  
    kinesis_source_configuration {
      kinesis_stream_arn = aws_kinesis_stream.clickstream.arn
      role_arn           = aws_iam_role.firehose_delivery_role.arn
    }
  
    extended_s3_configuration {
      role_arn   = aws_iam_role.firehose_delivery_role.arn
      bucket_arn = var.aws_s3_bucket_arn
      prefix     = "clickstream-data/"
       
      buffering_size = var.buffering_size
      buffering_interval = var.buffering_interval 
  
    }

  }


