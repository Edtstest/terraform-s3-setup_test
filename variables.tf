variable "AWS_ACCESS_KEY_ID" {
  description = "AWS9 access key"
  type        = string
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS3 secret key"
  type        = string
}


variable "bucket_name" {
  description = "Names of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}