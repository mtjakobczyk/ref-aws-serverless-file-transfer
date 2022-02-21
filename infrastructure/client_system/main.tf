
data "aws_region" "current" {}
data "aws_availability_zones" "azs" {}

##### Networking
resource "aws_vpc" "file_transfer_requester" {
  cidr_block = var.client_system_vpc_cidr
  tags = {
    Name = "${var.client_system_resource_prefix}-vpc"
    SystemName = "${var.client_system_resource_prefix}"
  }
}

resource "aws_subnet" "file_transfer_requester" {
  count = length(var.client_system_subnet_cidrs)
  vpc_id     = aws_vpc.file_transfer_requester.id
  cidr_block = var.client_system_subnet_cidrs[count.index] 
  availability_zone = "${data.aws_availability_zones.azs.names[count.index % 3]}"
  tags = {
    Name = "${var.client_system_resource_prefix}-subnet-${count.index}"
    SystemName = "${var.client_system_resource_prefix}"
  }
}

resource "aws_security_group" "file_transfer_service" {
  vpc_id      = aws_vpc.file_transfer_requester.id
  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [ aws_vpc.file_transfer_requester.cidr_block ]
  }
  tags = {
    Name = "${var.client_system_resource_prefix}-sg"
    SystemName = "${var.client_system_resource_prefix}"
  }
}

resource "aws_vpc_endpoint" "file_transfer_service" {
  vpc_id       = aws_vpc.file_transfer_requester.id
  vpc_endpoint_type = "Interface"
  service_name = "com.amazonaws.${data.aws_region.current.name}.execute-api"
  subnet_ids        =   aws_subnet.file_transfer_requester[*].id
  security_group_ids =  [
    aws_security_group.file_transfer_service.id
  ]
  # tags = {
  #   Name = "${var.client_system_resource_prefix}-vpcendpoint"
  # }
}


##### Datastore 
resource "aws_dynamodb_table" "file_transfers" {
  name           = "${var.client_system_resource_prefix}-requested-file-transfers"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key       = "fileProcessingId"
  attribute {
    name = "fileProcessingId"
    type = "S"
  }
  tags = {
    SystemName = "${var.client_system_resource_prefix}"
  }
}


##### Staging Bucket
resource "aws_s3_bucket" "staging" {
  bucket = var.staging_bucket_name
  tags = {
    SystemName = "${var.client_system_resource_prefix}"
  }
}

resource "aws_s3_bucket_acl" "staging" {
  bucket = aws_s3_bucket.staging.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "staging" {
  bucket = aws_s3_bucket.staging.id

  block_public_acls   = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}


##### IAM Role
data "aws_iam_policy_document" "file_transfer_requester" {
  statement {
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.staging.arn}/*",
    ]
  }
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:Update*",
      "dynamodb:DescribeTable",
    ]
    resources = [
      "${aws_dynamodb_table.file_transfers.arn}",
    ]
  }
  statement {
    sid = "AWSLambdaBasicExecutionRole"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role" "file_transfer_requester" {
  name               = "${var.file_transfer_requester_role_name}"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  inline_policy {
    name   = "AllowGetObject-${var.staging_bucket_name}"
    policy = data.aws_iam_policy_document.file_transfer_requester.json
  }
}