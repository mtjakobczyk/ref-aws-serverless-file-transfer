
data "aws_region" "current" {}

resource "aws_vpc" "file_transfer_requester" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "file-transfer-requester-vpc"
  }
}

resource "aws_subnet" "file_transfer_requester" {
  vpc_id     = aws_vpc.file_transfer_requester.id
  cidr_block = "192.168.1.0/24"
  tags = {
    Name = "file-transfer-requester-subnet"
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
}

resource "aws_vpc_endpoint" "file_transfer_service" {
  vpc_id       = aws_vpc.file_transfer_requester.id
  vpc_endpoint_type = "Interface"
  service_name = "com.amazonaws.${data.aws_region.current.name}.execute-api"
  subnet_ids        =   [ aws_subnet.file_transfer_requester.id ]
  security_group_ids =  [
    aws_security_group.file_transfer_service.id
  ]
}