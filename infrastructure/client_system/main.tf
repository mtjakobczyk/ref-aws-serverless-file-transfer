
data "aws_region" "current" {}
data "aws_availability_zones" "azs" {}

##### Networking
resource "aws_vpc" "file_transfer_requester" {
  cidr_block = var.client_system_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
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

resource "aws_security_group" "file_transfer_requester" {
  vpc_id      = aws_vpc.file_transfer_requester.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.client_system_resource_prefix}-requester-sg"
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
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.client_system_resource_prefix}-service-sg"
    SystemName = "${var.client_system_resource_prefix}"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.file_transfer_requester.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
}

resource "aws_vpc_endpoint_route_table_association" "s3" {
  route_table_id  = aws_vpc.file_transfer_requester.default_route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint" "cloudwatch" {
  vpc_id       = aws_vpc.file_transfer_requester.id
  vpc_endpoint_type = "Interface"
  service_name = "com.amazonaws.${data.aws_region.current.name}.logs"
  subnet_ids        =   aws_subnet.file_transfer_requester[*].id
  security_group_ids =  [
    aws_security_group.file_transfer_service.id
  ]
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.file_transfer_requester.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb" {
  route_table_id  = aws_vpc.file_transfer_requester.default_route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.dynamodb.id
}

resource "aws_vpc_endpoint" "file_transfer_service" {
  vpc_id       = aws_vpc.file_transfer_requester.id
  vpc_endpoint_type = "Interface"
  service_name = "com.amazonaws.${data.aws_region.current.name}.execute-api"
  subnet_ids        =   aws_subnet.file_transfer_requester[*].id
  security_group_ids =  [
    aws_security_group.file_transfer_service.id
  ]
  private_dns_enabled = true
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
      "s3:CopyObject",
      "s3:PutObject",
      "s3:DeleteObject",
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
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
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