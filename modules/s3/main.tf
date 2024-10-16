resource "aws_s3_bucket" "bucket" {
    bucket = var.s3_bucket_name
    acl    = "private"
  }
  

# Resource: Grant S3 permission to send messages to the SQS queue
resource "aws_sqs_queue_policy" "s3_sqs_policy" {
  count = var.sqs_queue_url == "" ? 0 : 1
  queue_url = var.sqs_queue_url

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = "SQS:SendMessage",
        Resource = var.sqs_queue_arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn": aws_s3_bucket.bucket.arn
          }
        }
      }
    ]
  })
}


# Resource: S3 bucket notification to send events to SQS queue
resource "aws_s3_bucket_notification" "s3_event_notification" {
  bucket = aws_s3_bucket.bucket.id
  count = var.sqs_queue_arn == "" ? 0 : 1


  queue {
    queue_arn     = var.sqs_queue_arn
    events        = ["s3:ObjectCreated:*"] # Trigger on all object creation events
    #filter_suffix = ".csv"                 # Optional: only trigger on specific file types (e.g., CSVs)
  }
}

 
  