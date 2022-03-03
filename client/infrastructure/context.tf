data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_string" "demo_prefix" {
  length  = 8
  special = false
  lower   = true
  number = true
  upper   = false
}

output "demo_prefix" { value = random_string.demo_prefix.result }