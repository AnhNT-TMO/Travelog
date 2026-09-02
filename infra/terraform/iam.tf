data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "thumbnailer" {
  name               = "${var.name_prefix}-thumbnailer-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "thumbnailer" {
  statement {
    sid       = "ReadOriginals"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.originals.arn}/*"]
  }

  statement {
    sid       = "WriteDerivatives"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.derivatives.arn}/*"]
  }

  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.thumbnailer.arn}:*"]
  }
}

resource "aws_iam_role_policy" "thumbnailer" {
  name   = "${var.name_prefix}-thumbnailer-${var.environment}"
  role   = aws_iam_role.thumbnailer.id
  policy = data.aws_iam_policy_document.thumbnailer.json
}

resource "aws_iam_user" "rails" {
  name = "${var.name_prefix}-rails-${var.environment}"
}

data "aws_iam_policy_document" "rails" {
  statement {
    sid = "ManageOriginals"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.originals.arn}/*"]
  }

  statement {
    sid       = "HeadBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.originals.arn]
  }
}

resource "aws_iam_user_policy" "rails" {
  name   = "${var.name_prefix}-rails-${var.environment}"
  user   = aws_iam_user.rails.name
  policy = data.aws_iam_policy_document.rails.json
}

resource "aws_iam_access_key" "rails" {
  user = aws_iam_user.rails.name
}
