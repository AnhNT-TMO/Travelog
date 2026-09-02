# CloudFront dung truoc bucket derivatives. Day chinh la CDN_HOST cua Rails.
#
# Bucket khong public: OAC ky request bang SigV4, chi CloudFront doc duoc.
resource "aws_cloudfront_origin_access_control" "derivatives" {
  name                              = "${var.name_prefix}-derivatives-${var.environment}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CachingOptimized — derivative la bat bien, key da mang size trong duong dan
# nen khong bao gio can invalidate.
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "derivatives" {
  enabled     = true
  comment     = "${var.name_prefix} photo derivatives (${var.environment})"
  price_class = var.cloudfront_price_class

  origin {
    origin_id                = "derivatives"
    domain_name              = aws_s3_bucket.derivatives.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.derivatives.id
  }

  default_cache_behavior {
    target_origin_id       = "derivatives"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.optimized.id
    compress               = true
  }

  # 404 khi Lambda chua sinh xong derivative la trang thai BINH THUONG trong
  # 1-3 giay dau. Cache ngan de anh hien ra ngay khi co, thay vi ket 404 lai.
  custom_error_response {
    error_code            = 403
    error_caching_min_ttl = 5
  }

  custom_error_response {
    error_code            = 404
    error_caching_min_ttl = 5
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Chi CloudFront distribution nay duoc doc bucket derivatives.
data "aws_iam_policy_document" "derivatives_cloudfront" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.derivatives.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.derivatives.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "derivatives" {
  bucket = aws_s3_bucket.derivatives.id
  policy = data.aws_iam_policy_document.derivatives_cloudfront.json

  depends_on = [aws_s3_bucket_public_access_block.derivatives]
}
