
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

  policy = var.file_ingestion_api_resource_policy

  endpoint_configuration {
    types = ["PRIVATE"]
    vpc_endpoint_ids = var.file_ingestion_connected_vpc_endpoints_ids
  }
}

# resource "aws_api_gateway_deployment" "file_ingestion" {
#   rest_api_id = aws_api_gateway_rest_api.file_ingestion.id

#   triggers = {
#     redeployment = sha1(templatefile("${path.module}/openapi/openapi.yaml.tftpl", { api_iam_role_name = "${aws_iam_role.file_ingestion.name}", file_ingestion_bucket_name = "${aws_s3_bucket.file_ingestion.id}" }))
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_api_gateway_stage" "file_ingestion" {
#   deployment_id = aws_api_gateway_deployment.file_ingestion.id
#   rest_api_id   = aws_api_gateway_rest_api.file_ingestion.id
#   stage_name    = "v1"
# }