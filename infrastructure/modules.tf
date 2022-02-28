
module "file_service" {
  source = "./file_service"
  file_ingestion_bucket_name = "${random_string.demo_prefix.result}-file-ingestion"
  file_ingestion_role_name = "${random_string.demo_prefix.result}-file-ingestion-role"
  file_ingestion_connected_vpc_endpoints_ids = [ module.client_one.client_vpc_endpoints ]
  # file_ingestion_api_resource_policy = data.aws_iam_policy_document.file_ingestion_resource_policy.json

  client_data = [ local.client_one_for_service ]
}

# output "file_ingestion_resource_policy" { value = data.aws_iam_policy_document.file_ingestion_resource_policy.json }
output "file_ingestion_api" { value = "${module.file_service.file_ingestion_api}" }

##### Client 1
locals {
  client_one_for_service = {
    system_name = "${random_string.demo_prefix.result}-clientOne"
    client_partition = "one"
    aws_account_id = data.aws_caller_identity.current.account_id
    region = "eu-west-1"
    file_transfer_requester_role_name = "${lower(random_string.demo_prefix.result)}-clientOne-file-transfer-requester"
    vpc_endpoint = module.client_one.client_vpc_endpoints
  }
}
locals {
  client_one = {
    system_name = "${random_string.demo_prefix.result}-clientOne"
    client_partition = "one"
    aws_account_id = data.aws_caller_identity.current.account_id
    file_transfer_requester_role_name = "${lower(random_string.demo_prefix.result)}-clientOne-file-transfer-requester"
  }
}

module "client_one" {
  source = "./client_system"
  client_system_resource_prefix = "${local.client_one["system_name"]}"
  staging_bucket_name = "${lower(local.client_one["system_name"])}-staging"
  file_transfer_requester_role_name = "${local.client_one["file_transfer_requester_role_name"]}"
  client_system_vpc_cidr = "192.168.0.0/16"
  client_system_subnet_cidrs = [ "192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24" ]
}

module "client_one_file_transfer_requester" {
  source = "./s3_triggered_lambda"
  system_name = "${local.client_one["system_name"]}"
  function_name = "${lower(local.client_one["system_name"])}-file-transfer-requester"

  # Codebase
  codebase_bucket_name = "${lower(local.client_one["system_name"])}-codebase"
  codebase_package_path = "${path.root}/../applications/fileTransferRequester/target/file-transfer-requester-1.0-SNAPSHOT.jar"
  codebase_package_name = "file-transfer-requester-1.0-SNAPSHOT.jar"

  # Runtime
  runtime = "java11" # Amazon Corretto 11
  handler = "io.github.mtjakobczyk.references.aws.serverless.FileTransferRequester::handleRequest"
  execution_role_arn = module.client_one.execution_role_arn
  timeout = "120" # seconds
  memory_size = "512" # MBs

  vpc_subnets = module.client_one.vpc_subnets
  vpc_security_groups = module.client_one.vpc_security_groups
  
  # Event Source
  s3_bucket_event_source_arn = module.client_one.staging_bucket_arn
  s3_bucket_event_source_id = module.client_one.staging_bucket_id
  s3_object_prefix_filter = "in/"
  # s3_object_prefix_suffix = ".txt"
  
  # Function's Environment Variables
  function_environment_variables = {
    FILE_TRANSFERS_TABLE = module.client_one.dynamodb_table_file_transfers_name
    FILE_TRANSFER_API_INVOKE_URL = "1q44ukvux1.execute-api.eu-west-1.amazonaws.com"
    FILE_TRANSFER_API_VPCE_HOSTNAME = "vpce-07ec1500a6f5e2656-745cdpea.execute-api.eu-west-1.vpce.amazonaws.com"
    FILE_TRANSFER_API_BASEPATH = "v1"
  }
  
}
