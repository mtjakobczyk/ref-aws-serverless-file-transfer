# file-service module - vars.tf

## Module Input Variables
variable "file_ingestion_bucket_name" {}
variable "file_ingestion_role_name" {}
variable "file_ingestion_api_resource_policy" {}
variable "file_ingestion_connected_vpc_endpoints_ids" {
  type=list(string)
}