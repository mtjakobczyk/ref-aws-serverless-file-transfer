# file-service module - vars.tf

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

## Module Input Variables
variable "file_ingestion_bucket_name" {}
variable "file_ingestion_role_name" {}
# variable "file_ingestion_api_resource_policy" {}

variable "client_data" {
  type=list(map(string))
}