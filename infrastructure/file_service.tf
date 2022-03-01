
module "file_service" {
  source = "./file_service"
  file_ingestion_bucket_name = "${random_string.demo_prefix.result}-file-ingestion"
  file_ingestion_role_name = "${random_string.demo_prefix.result}-file-ingestion-role"

  client_data = local.registered_clients
}

locals {
  registered_clients = [
    {
      client_partition = "one"
      vpc_endpoint = module.client_one.client_vpc_endpoints
    }
  ]
}

output "file_ingestion_api" { value = "${module.file_service.file_ingestion_api_id}" }
output "file_ingestion_api_dns_name" { value = "${module.file_service.file_ingestion_api_dns_name}" }