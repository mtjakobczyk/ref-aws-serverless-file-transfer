
module "file-service" {
  source = "./file-service"
  file_ingestion_bucket_name = "${random_string.demo_prefix.result}-file-ingestion"
  file_ingestion_role_name = "${random_string.demo_prefix.result}-file-ingestion-role"
  file_ingestion_connected_vpc_endpoints_ids = ["${module.client_system.client_vpc_endpoint}"]
}

module "client_system" {
  source = "./client_system"
}