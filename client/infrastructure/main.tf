
locals {
  system_name = "${lower(random_string.demo_prefix.result)}-client-${lower(var.client_name)}"
  s3_folder_in = "in"
  s3_folder_accepted = "accepted"
  s3_folder_rejected = "rejected"
}

#### Client Infrastructure (Staging S3, VPC, Endpoints, DynamoDB)
module "client_infrastructure" {
  source = "./client_system"
  client_system_resource_prefix = local.system_name
  staging_bucket_name = "${local.system_name}-staging"
  s3_folder_in = local.s3_folder_in
  s3_folder_accepted = local.s3_folder_accepted
  s3_folder_rejected = local.s3_folder_rejected
  file_transfer_requester_role_name = "${local.system_name}-file-transfer-requester"
  client_system_vpc_cidr = var.client_system_vpc_cidr
  client_system_subnet_cidrs = var.client_system_subnet_cidrs
}

#### Client Infrastructure (Lambda)
module "client_serverless_file_transfer_requester" {
  source = "./s3_triggered_lambda"
  system_name = local.system_name
  function_name = "${local.system_name}-file-transfer-requester"

  # Codebase
  codebase_bucket_name = "${local.system_name}-codebase"
  codebase_package_path = "${path.root}/../applications/fileTransferRequester/target/file-transfer-requester-1.0-SNAPSHOT.jar"
  codebase_package_name = "file-transfer-requester-1.0-SNAPSHOT.jar"

  # Runtime
  runtime = "java11" # Amazon Corretto 11
  handler = "io.github.mtjakobczyk.references.aws.serverless.FileTransferRequester::handleRequest"
  execution_role_arn = module.client_infrastructure.execution_role_arn
  timeout = "120" # seconds
  memory_size = "512" # MBs

  vpc_subnets = module.client_infrastructure.vpc_subnets
  vpc_security_groups = module.client_infrastructure.vpc_security_groups
  
  # Event Source
  s3_bucket_event_source_arn = module.client_infrastructure.staging_bucket_arn
  s3_bucket_event_source_id = module.client_infrastructure.staging_bucket_id
  s3_object_prefix_filter = "${local.s3_folder_in}/"
  
  # Function's Environment Variables
  function_environment_variables = {
    FILE_TRANSFERS_TABLE = module.client_infrastructure.dynamodb_table_file_transfers_name
    FILE_TRANSFER_API_INVOKE_URL = var.file_ingestion_api_dns_name
    FILE_TRANSFER_API_VPCE_HOSTNAME = module.client_infrastructure.vpce_dns_entries[0].dns_name
    FILE_TRANSFER_API_BASEPATH = var.file_ingestion_api_stage
    CLIENT_PARTITION = var.client_partition
    S3_FOLDER_ACCEPTED = local.s3_folder_accepted
    S3_FOLDER_REJECTED = local.s3_folder_rejected
  }
}

output "vpce_dns_entry" { value = module.client_infrastructure.vpce_dns_entries[0].dns_name }
output "staging_bucket_id" { value = module.client_infrastructure.staging_bucket_id }
output "vpce_id" { value = module.client_infrastructure.vpce_id }