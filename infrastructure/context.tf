data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  default_tags = {
     "ref:aws:environment" = "demo"
     "ref:aws:scenario"    = "ref-aws-serverless-file-transfer"
  }
}

resource "random_string" "demo_prefix" {
  length  = 8
  special = false
  lower   = true
  number = true
  upper   = false
}

output "demo_prefix" { value = random_string.demo_prefix.result }