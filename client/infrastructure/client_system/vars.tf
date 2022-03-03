# client_system module - vars.tf

## Module Input Variables
variable "client_system_resource_prefix" {}
variable "staging_bucket_name" {}
variable "file_transfer_requester_role_name" {}
variable "client_system_vpc_cidr" {}
variable "client_system_subnet_cidrs" {
  type=list(string)
  default = []
}
variable "s3_folder_in" {}
variable "s3_folder_accepted" {}
variable "s3_folder_rejected" {}