resource "aws_s3_bucket" "my_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = "My1S3Bucket"
    Environment = var.environment
  }




}