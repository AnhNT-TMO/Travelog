output "cdn_host" {
  description = "CDN_HOST. Khong co dau / o cuoi."
  value       = "https://${aws_cloudfront_distribution.derivatives.domain_name}"
}

output "s3_bucket_originals" {
  description = "S3_BUCKET_ORIGINALS"
  value       = aws_s3_bucket.originals.id
}

output "s3_bucket_derivatives" {
  description = "S3_BUCKET_DERIVATIVES"
  value       = aws_s3_bucket.derivatives.id
}

output "aws_region" {
  description = "AWS_REGION"
  value       = var.aws_region
}

output "rails_access_key_id" {
  description = "AWS_ACCESS_KEY_ID cho Rails"
  value       = aws_iam_access_key.rails.id
}

output "rails_secret_access_key" {
  description = "AWS_SECRET_ACCESS_KEY cho Rails. Doc bang: terraform output -raw rails_secret_access_key"
  value       = aws_iam_access_key.rails.secret
  sensitive   = true
}

output "lambda_function_name" {
  value = aws_lambda_function.thumbnailer.function_name
}
