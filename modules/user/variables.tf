# Variables for S3 bucket name and prefix
variable "s3_bucket_arn" {
  description = "The arn of the S3 bucket"
  type        = string
}

variable "s3_prefix" {
  description = "The prefix for the S3 objects"
  type        = string
}

variable "user_name" {
    description = "Name of the user"
    type        = string
  }