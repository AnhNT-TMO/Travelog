locals {
  originals_bucket   = "${var.name_prefix}-originals-${var.environment}"
  derivatives_bucket = "${var.name_prefix}-derivatives-${var.environment}"
}

# ---------------------------------------------------------------------------
# Bucket originals — trinh duyet PUT thang vao day bang presigned URL.
# Khong bao gio public: CloudFront chi doc bucket derivatives.
# ---------------------------------------------------------------------------
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

  # Anh goc la thu duy nhat khong tai tao lai duoc: derivative sinh lai duoc,
  # anh goc thi khong. Versioning la luoi cuoi cho mot lenh xoa nham.
  versioning_configuration {
    status = "Enabled"
  }
}

# CORS: khong co block nay thi direct upload chet o preflight, va loi hien ra
# trong console trinh duyet chu khong o log Rails.
# ETag phai duoc expose, Active Storage doc no de xac nhan upload thanh cong.
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

    # Upload dut giua chung de lai phan da tai len va van bi tinh tien.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# Bucket derivatives — Lambda ghi, CloudFront doc. Khong ai khac cham vao.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "derivatives" {
  bucket = local.derivatives_bucket
}

resource "aws_s3_bucket_public_access_block" "derivatives" {
  bucket = aws_s3_bucket.derivatives.id

  block_public_acls       = true
  block_public_policy     = false # policy cho CloudFront OAC can ghi duoc
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

# Khong versioning: derivative sinh lai duoc tu anh goc bat cu luc nao.

# ---------------------------------------------------------------------------
# S3 -> Lambda trigger
# ---------------------------------------------------------------------------
resource "aws_s3_bucket_notification" "originals" {
  bucket = aws_s3_bucket.originals.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.thumbnailer.arn
    events              = ["s3:ObjectCreated:*"]
  }

  # Khong co depends_on thi Terraform tao notification truoc permission va S3
  # tu choi voi "Unable to validate the following destination configurations".
  depends_on = [aws_lambda_permission.allow_s3]
}
