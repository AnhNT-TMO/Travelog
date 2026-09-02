data "archive_file" "thumbnailer" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/thumbnailer.zip"
  excludes    = ["test"]
}

resource "aws_lambda_function" "thumbnailer" {
  function_name = "${var.name_prefix}-thumbnailer-${var.environment}"
  role          = aws_iam_role.thumbnailer.arn
  handler       = "src/index.handler"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]

  filename         = data.archive_file.thumbnailer.output_path
  source_code_hash = data.archive_file.thumbnailer.output_base64sha256

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_s

  environment {
    variables = {
      DERIVATIVES_BUCKET = aws_s3_bucket.derivatives.id
      IMAGE_SIZES        = join(",", var.image_sizes)
      WEBP_QUALITY       = tostring(var.webp_quality)
    }
  }

  depends_on = [aws_cloudwatch_log_group.thumbnailer]

  lifecycle {
    precondition {
      condition     = fileexists("${path.module}/../lambda/node_modules/sharp/package.json")
      error_message = "Chua build Lambda. Chay: cd infra/lambda && npm run build"
    }
  }
}

resource "aws_cloudwatch_log_group" "thumbnailer" {
  name              = "/aws/lambda/${var.name_prefix}-thumbnailer-${var.environment}"
  retention_in_days = 14
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id   = "AllowExecutionFromS3"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.thumbnailer.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.originals.arn
  source_account = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}
