
#### Client One Parameters
locals {
  client_one = {
    system_name = "${random_string.demo_prefix.result}-clientOne"
    client_partition = "one"
    aws_account_id = data.aws_caller_identity.current.account_id
    file_transfer_requester_role_name = "${lower(random_string.demo_prefix.result)}-clientOne-file-transfer-requester"
  }
}

#### Client Infrastructure (Staging S3, VPC, Endpoints, DynamoDB)
module "client_one" {
  source = "./client_system"
  client_system_resource_prefix = "${local.client_one["system_name"]}"
  staging_bucket_name = "${lower(local.client_one["system_name"])}-staging"
  file_transfer_requester_role_name = "${local.client_one["file_transfer_requester_role_name"]}"
  client_system_vpc_cidr = "192.168.0.0/16"
  client_system_subnet_cidrs = [ "192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24" ]
}

#### Client Infrastructure (Lambda)
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
  
  # Function's Environment Variables
  function_environment_variables = {
    FILE_TRANSFERS_TABLE = module.client_one.dynamodb_table_file_transfers_name
    FILE_TRANSFER_API_INVOKE_URL = module.file_service.file_ingestion_api_dns_name
    FILE_TRANSFER_API_VPCE_HOSTNAME = module.client_one.vpce_dns_entries[0].dns_name
    FILE_TRANSFER_API_BASEPATH = "v1"
    CLIENT_PARTITION = "${local.client_one["client_partition"]}"
    S3_FOLDER_ACCEPTED = "accepted"
    S3_FOLDER_REJECTED = "rejected"
  }
}

output "vpce_dns_entry" { value = module.client_one.vpce_dns_entries[0].dns_name }