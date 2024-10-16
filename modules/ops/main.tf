resource "aws_sns_topic" "monitoring" {
    name = "clickstream_monitoring"
  }
  
  resource "aws_sns_topic_subscription" "email" {
    topic_arn = aws_sns_topic.monitoring.arn
    protocol  = "email"
    endpoint  = var.sns_email  # Replace with your email
  }
  

  resource "aws_cloudwatch_metric_alarm" "kinesis_put_records_success" {
    alarm_name          = "KinesisPutRecordsSuccess"
    comparison_operator = "LessThanThreshold"
    evaluation_periods  = "1"
    metric_name         = "PutRecord.Success"
    namespace           = "AWS/Kinesis"
    period              = "60"
    statistic           = "Average"
    threshold           = "1"
    dimensions = {
      StreamName = var.clickstream_name
    }
    alarm_description = "Alarm when the success rate of Kinesis PutRecord is too low"
    alarm_actions     = [aws_sns_topic.monitoring.arn]
  }

  resource "aws_cloudwatch_dashboard" "clickstream_dashboard" {
    dashboard_name = "ClickstreamPOC"
  
    dashboard_body = jsonencode({
      widgets = [
        {
          "type" : "metric",
          "x" : 0,
          "y" : 0,
          "width" : 12,
          "height" : 6,
          "properties" : {
            "metrics" : [
              [ "AWS/Kinesis", "IncomingBytes", "StreamName", var.clickstream_name ],
              [ "AWS/Firehose", "IncomingRecords", "DeliveryStreamName", var.clickstream_firehose_name ]
            ],
            "period" : 60,
            "stat" : "Sum",
            "region" : "us-east-1",
            "title" : "Kinesis and Firehose Data Flow"
          }
        },
        {
          "type" : "metric",
          "x" : 0,
          "y" : 7,
          "width" : 12,
          "height" : 6,
          "properties" : {
            "metrics" : [
              [ "AWS/EC2", "CPUUtilization", "InstanceId", var.kinesis_producer_id ]
            ],
            "period" : 60,
            "stat" : "Average",
            "region" : "us-east-1",
            "title" : "EC2 CPU Utilization"
          }
        }
      ]
    })
  }
  
