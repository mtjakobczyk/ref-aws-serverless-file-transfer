# s3_triggered_lambda module - vars.tf

## Module Input Variables
variable "system_name" {}
variable "codebase_bucket_name" {}
variable "codebase_package_path" {}
variable "codebase_package_name" {}
variable "runtime" {}
variable "function_name" {}
variable "execution_role_arn" {}
variable "handler" {}
variable "timeout" {}
variable "memory_size" {}

variable "s3_bucket_event_source_arn" {}
variable "s3_bucket_event_source_id" {}
variable "s3_object_prefix_filter" {}
variable "s3_object_prefix_suffix" {}
variable "s3_object_events" {
  type=list(string)
  default = [ "s3:ObjectCreated:*" ]
}
variable "vpc_subnets" { type=list(string) }
variable "vpc_security_groups" { type=list(string) }

variable "function_environment_variables" {
  type=map(string)
  default = {}
}