
output "file_ingestion_api_id" { value = "${aws_api_gateway_rest_api.file_ingestion.id}" }
output "file_ingestion_api_dns_name" { value = trimsuffix(trimprefix(aws_api_gateway_deployment.file_ingestion.invoke_url, "https://"),"/")  }
