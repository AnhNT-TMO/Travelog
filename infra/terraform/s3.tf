locals {
  originals_bucket   = "${var.name_prefix}-originals-${var.environment}"
  derivatives_bucket = "${var.name_prefix}-derivatives-${var.environment}"
}

resource "aws_s3_bucket" "originals" {
  bucket = local.originals_bucket
}

resource "aws_s3_bucket_public_access_block" "originals" {
  bucket = aws_s3_bucket.originals.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "originals" {
  bucket = aws_s3_bucket.originals.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "originals" {
  bucket = aws_s3_bucket.originals.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_cors_configuration" "originals" {
  bucket = aws_s3_bucket.originals.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "HEAD", "GET"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag", "Origin", "Content-Type", "Content-Disposition", "Content-Length"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "originals" {
  count  = var.originals_expiration_days > 0 ? 1 : 0
  bucket = aws_s3_bucket.originals.id

  rule {
    id     = "originals-to-infrequent-access"
    status = "Enabled"

    filter {}

    transition {
      days          = var.originals_expiration_days
      storage_class = "STANDARD_IA"
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket" "derivatives" {
  bucket = local.derivatives_bucket
}

resource "aws_s3_bucket_public_access_block" "derivatives" {
  bucket = aws_s3_bucket.derivatives.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_server_side_encryption_configuration" "derivatives" {
  bucket = aws_s3_bucket.derivatives.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_notification" "originals" {
  bucket = aws_s3_bucket.originals.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.thumbnailer.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
