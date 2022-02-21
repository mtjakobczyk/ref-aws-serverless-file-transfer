# s3_triggered_lambda module - main.tf

resource "aws_s3_bucket" "codebase" {
  bucket = var.codebase_bucket_name
  tags = {
    SystemName = "${var.system_name}"
  }
}

resource "aws_s3_bucket_acl" "codebase" {
  bucket = aws_s3_bucket.codebase.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "codebase" {
  bucket = aws_s3_bucket.codebase.id

  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}

resource "aws_s3_object" "code_package" {
  bucket = aws_s3_bucket.codebase.id
  key    = var.codebase_package_name
  source = var.codebase_package_path
  etag = filemd5(var.codebase_package_path) # Triggers updates when the value changes
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.arn
  principal     = "s3.amazonaws.com"
  source_arn    = var.s3_bucket_event_source_arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.s3_bucket_event_source_id
  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "in/"
    filter_suffix       = ".txt"
  }
  depends_on = [aws_lambda_permission.allow_bucket]
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role = var.execution_role_arn

  s3_bucket = aws_s3_bucket.codebase.id
  s3_key    = aws_s3_object.code_package.key

  runtime = var.runtime
  handler = var.handler
  timeout = var.timeout
  memory_size = var.memory_size

  source_code_hash = filebase64sha256(var.codebase_package_path) # Triggers updates when the value changes

  environment {
    variables = var.function_environment_variables
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 7
}

