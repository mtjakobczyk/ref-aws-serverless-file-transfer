
# module "file_service" {
#   source = "./file_service"
#   file_ingestion_bucket_name = "${random_string.demo_prefix.result}-file-ingestion"
#   file_ingestion_role_name = "${random_string.demo_prefix.result}-file-ingestion-role"
#   file_ingestion_connected_vpc_endpoints_ids = [ module.client_one.client_vpc_endpoints ]
#   file_ingestion_api_resource_policy = data.aws_iam_policy_document.file_ingestion_resource_policy.json
# }

# data "aws_iam_policy_document" "file_ingestion_resource_policy" {
#   statement {
#     effect = "Allow"
#     principals {
#       type        = "AWS"
#       identifiers = [ "arn:aws:iam::${local.client_one["aws_account_id"]}:role/${local.client_one["file_transfer_requester_role_name"]}" ]
#     }
#     actions   = ["execute-api:Invoke"]
#     resources = ["execute-api:/${local.file_ingestion_stage}/POST/clients/${local.client_one["client_partition"]}/*"]
#     condition {
#       test     = "StringEquals"
#       variable = "aws:SourceVpce"
#       values = [ module.client_one.client_vpc_endpoints ]
#     }
#   }
# }

# output "file_ingestion_resource_policy" { value = data.aws_iam_policy_document.file_ingestion_resource_policy.json }

##### Client 1
locals {
  file_ingestion_stage = "v1"
  client_one = {
    system_name = "${random_string.demo_prefix.result}-clientOne"
    client_partition = "one"
    aws_account_id = ""
    file_transfer_requester_role_name = "${lower(random_string.demo_prefix.result)}-clientOne-file-transfer-requester"
  }
}

# module "client_one" {
#   source = "./client_system"
#   client_system_resource_prefix = "${local.client_one["system_name"]}"
#   staging_bucket_name = "${lower(local.client_one["system_name"])}-staging"
#   file_transfer_requester_role_name = "${local.client_one["file_transfer_requester_role_name"]}"
#   client_system_vpc_cidr = "192.168.0.0/16"
#   client_system_subnet_cidrs = [ "192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24" ]
# }

module "client_one_file_transfer_requester" {
  source = "./lambda"
  system_name = "${local.client_one["system_name"]}"
  codebase_bucket_name = "${lower(local.client_one["system_name"])}-codebase"
  codebase_package_path = "${path.root}/../applications/fileTransferRequester/target/file-transfer-requester-1.0-SNAPSHOT-jar-with-dependencies.jar"
  codebase_package_name = "file-transfer-requester-1.0-SNAPSHOT-jar-with-dependencies.jar"
  runtime = "java11" # Amazon Corretto 11
  function_name = "${lower(local.client_one["system_name"])}-file-transfer-requester"
  execution_role_name = "${lower(local.client_one["system_name"])}-file-transfer-requester"
  handler = "io.github.mtjakobczyk.references.aws.serverless.FileTransferRequester::handleRequest"
  timeout = "3" # seconds
  memory_size = "128" # MBs
}
