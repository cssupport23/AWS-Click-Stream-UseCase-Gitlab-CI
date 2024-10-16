variable "stream_name" {
    type = string
  }

variable "shard_count" {
    type = number 
    default = 1
}

variable "retention_period" {
    type = number
    default = 24
}

variable "aws_s3_bucket_arn" {
    type = string
}

variable "firehose_name" {
   type = string
}

variable "buffering_size" {
    type = number 
    default = 5

}

variable "buffering_interval" {
    type = number
    default = 300
}