variable "instance_type" {
  type = string
  default = "t2.micro"
}

variable "ami" {
  type = string
  default = "ami-08718895af4dfa033"
}

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

variable "firehose_name" {
 type = string
}

variable "s3_bucket_name" {
  type = string
  
}

variable "sqs_queue_arn" {
  type = string 
  default = ""
}

variable "sqs_queue_url" {
  type = string
  default = ""
}

variable "buffering_size" {
  type = number 
  default = 5

}

variable "buffering_interval" {
  type = number
  default = 300
}

variable "s3_prefix" {
  description = "The prefix for the S3 objects"
  type        = string
}

variable "user_name" {
    description = "Name of the user"
    type        = string
  }

  variable "sns_email" {}