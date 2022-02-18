# lambda module - vars.tf

## Module Input Variables
variable "system_name" {}
variable "codebase_bucket_name" {}
variable "codebase_package_path" {}
variable "codebase_package_name" {}
variable "runtime" {}
variable "function_name" {}
variable "execution_role_name" {}
variable "handler" {}
variable "timeout" {}
variable "memory_size" {}