terraform {
  required_version = ">= 1.1.5"

  backend "s3" { }

  required_providers {
    # https://registry.terraform.io/providers/hashicorp/aws/latest
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.1.0"
    }

    # https://registry.terraform.io/providers/hashicorp/random/latest
    random = {
      source  = "hashicorp/random"
      version = ">= 3.1.0"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      "ref:aws:environment"  = "demo"
      "ref:aws:scenario"     = "ref-aws-serverless-file-transfer"
      "ref:aws:system"       = "service"
    }
  }
}
