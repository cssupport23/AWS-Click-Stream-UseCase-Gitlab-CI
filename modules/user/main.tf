

# Create IAM Policy
resource "aws_iam_policy" "s3_access_policy" {
  name        = "S3AccessPolicy"
  description = "IAM policy for accessing specific objects in an S3 bucket"
  policy      = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ],
        "Resource": "${var.s3_bucket_arn}/*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Resource": var.s3_bucket_arn,
        "Condition": {
          "StringLike": {
            "s3:prefix": [
              "${var.s3_prefix}/*"
            ]
          }
        }
      }
    ]
  })
}

# Create IAM User (programmatic access only)
resource "aws_iam_user" "programmatic_user" {
  name = var.user_name
  force_destroy = true  # Set to true to automatically delete the user upon Terraform destroy

  tags = {
    Name = var.user_name
  }
}

# Attach the policy to the IAM user
resource "aws_iam_user_policy_attachment" "user_policy_attachment" {
  user       = aws_iam_user.programmatic_user.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Create access keys for the user
#resource "aws_iam_access_key" "programmatic_access_key" {
#  user = aws_iam_user.programmatic_user.name

#  # Save the access key and secret in output or secrets manager
#  lifecycle {
#    create_before_destroy = true
#  }

#  # Store access key and secret key securely
#  # You can use outputs or integrate with secrets management tools here
#}

# Output the access key and secret for reference
#output "access_key" {
#  description = "Access key for programmatic access"
#  value       = aws_iam_access_key.programmatic_access.id
#}

#output "secret_key" {
#  description = "Secret key for programmatic access"
#  value       = aws_iam_access_key.programmatic_access.secret
#  sensitive   = true
#}

