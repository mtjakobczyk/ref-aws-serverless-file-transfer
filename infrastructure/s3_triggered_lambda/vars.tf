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

variable "function_environment_variables" {
  type=map(string)
  default = {}
}