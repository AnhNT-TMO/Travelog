resource "aws_cloudfront_origin_access_control" "derivatives" {
  name                              = "${var.name_prefix}-derivatives-${var.environment}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

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
