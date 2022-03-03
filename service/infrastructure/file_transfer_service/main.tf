
resource "aws_s3_bucket" "file_ingestion" {
  bucket = var.file_ingestion_bucket_name
}

resource "aws_s3_bucket_acl" "file_ingestion" {
  bucket = aws_s3_bucket.file_ingestion.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "file_ingestion" {
  bucket = aws_s3_bucket.file_ingestion.id

  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}

data "aws_iam_policy_document" "file_ingestion_put_object" {
  statement {
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.file_ingestion.arn}/*",
    ]
  }
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]
    resources = [
      "${aws_s3_bucket.file_ingestion.arn}/*",
    ]
  }
}

resource "aws_iam_role" "file_ingestion" {
  name               = "${var.file_ingestion_role_name}"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  inline_policy {
    name   = "AllowPutObject-${var.file_ingestion_bucket_name}"
    policy = data.aws_iam_policy_document.file_ingestion_put_object.json
  }
}

resource "aws_api_gateway_rest_api" "file_ingestion" {
  body = templatefile("${path.module}/openapi/openapi.yaml.tftpl", { api_iam_role_name = "${aws_iam_role.file_ingestion.name}", file_ingestion_bucket_name = "${aws_s3_bucket.file_ingestion.id}" })
  name = "file-transfer-service"

  endpoint_configuration {
    types = ["PRIVATE"]
    vpc_endpoint_ids = (length(var.client_data)>0) ? var.client_data[*].vpc_endpoint : null
  }
}

resource "aws_api_gateway_deployment" "file_ingestion" {
  rest_api_id = aws_api_gateway_rest_api.file_ingestion.id

  triggers = {
    redeployment = sha1(join("",[
      sha1(templatefile("${path.module}/openapi/openapi.yaml.tftpl", { api_iam_role_name = "${aws_iam_role.file_ingestion.name}", file_ingestion_bucket_name = "${aws_s3_bucket.file_ingestion.id}" })),
      sha1((length(var.client_data)>0) ? data.aws_iam_policy_document.file_ingestion_resource_policy.json : data.aws_iam_policy_document.default_deny_all.json)
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_rest_api_policy.file_ingestion,
  ]
}

resource "aws_api_gateway_stage" "file_ingestion" {
  deployment_id = aws_api_gateway_deployment.file_ingestion.id
  rest_api_id   = aws_api_gateway_rest_api.file_ingestion.id
  stage_name    = "v1"
}

resource "aws_api_gateway_rest_api_policy" "file_ingestion" {
  rest_api_id = aws_api_gateway_rest_api.file_ingestion.id
  policy = (length(var.client_data)>0) ? data.aws_iam_policy_document.file_ingestion_resource_policy.json : data.aws_iam_policy_document.default_deny_all.json
}

# https://github.com/awsdocs/amazon-api-gateway-developer-guide/blob/main/doc_source/api-gateway-control-access-using-iam-policies-to-invoke-api.md
data "aws_iam_policy_document" "file_ingestion_resource_policy" {
  dynamic "statement" {
    for_each = var.client_data
    content {
      effect = "Allow"
      principals {
        type        = "*"
        identifiers = [ "*" ]
      }
      actions   = ["execute-api:Invoke"]
      resources = ["arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.file_ingestion.id}/v1/POST/clients/${statement.value["client_partition"]}/*"]
      condition {
        test     = "StringEquals"
        variable = "aws:SourceVpce"
        values = [ statement.value["vpc_endpoint"] ]
      }
    }
  }
}

data "aws_iam_policy_document" "default_deny_all" {
  statement {
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = [ "*" ]
    }
    actions   = ["execute-api:Invoke"]
    resources = ["arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.file_ingestion.id}/*"]
  }
}