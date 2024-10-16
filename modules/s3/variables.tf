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