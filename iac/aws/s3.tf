resource "aws_s3_bucket" "web" {
  bucket = "${var.app-name}-${var.environment}-web-${random_string.suffix.result}"
  tags   = {}
}

resource "aws_s3_bucket_public_access_block" "web" {
  block_public_acls       = true
  block_public_policy     = true
  bucket                  = aws_s3_bucket.web.bucket
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "web" {
  bucket = aws_s3_bucket.web.bucket

  versioning_configuration {
    status = "Disabled"
  }
}

# S3バケットポリシー CloudFrontからのGETを許可
resource "aws_s3_bucket_policy" "web" {
  bucket = aws_s3_bucket.web.bucket
  policy = jsonencode(
    {
      Id = "PolicyForCloudFrontPrivateContent"
      Statement = [
        {
          Action = "s3:GetObject"
          Condition = {
            StringEquals = {
              "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
            }
          }
          Effect = "Allow"
          Principal = {
            Service = "cloudfront.amazonaws.com"
          }
          Resource = "${aws_s3_bucket.web.arn}/*"
          Sid      = "AllowCloudFrontServicePrincipal"
        },
      ]
      Version = "2008-10-17"
    }
  )
}
