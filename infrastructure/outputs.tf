output "file_ingestion_api" { value = "${module.file_service.file_ingestion_api_id}" }
output "file_ingestion_api_dns_name" { value = "${module.file_service.file_ingestion_api_dns_name}" }
output "vpce_dns_entry" { value = module.client_one.vpce_dns_entries[0].dns_name }