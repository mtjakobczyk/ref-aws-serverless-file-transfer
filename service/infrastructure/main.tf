
resource "random_string" "demo_prefix" {
  length  = 8
  special = false
  lower   = true
  number = true
  upper   = false
}
output "demo_prefix" { value = random_string.demo_prefix.result }


locals {
  registered_clients = [
    # {
    #   client_partition = "one"
    #   vpc_endpoint = "vpce-................."
    # }
  ]
}
module "file_transfer_service" {
  source = "./file_transfer_service"
  file_ingestion_bucket_name = "${random_string.demo_prefix.result}-file-ingestion"
  file_ingestion_role_name = "${random_string.demo_prefix.result}-file-ingestion-role"

  client_data = local.registered_clients
}
output "service_api" { value = "${module.file_transfer_service.file_ingestion_api_id}" }
output "service_dns_name" { value = "${module.file_transfer_service.file_ingestion_api_dns_name}" }



