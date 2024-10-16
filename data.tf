data "aws_ssm_parameter" "env" {
  name = "env"
}

data "aws_ssm_parameter" "vpc_id" {
  name = "vpc_id"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}