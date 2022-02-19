
output "client_vpc_endpoints" { value = aws_vpc_endpoint.file_transfer_service.id }
output "staging_bucket_arn" { value = aws_s3_bucket.staging.arn }
output "staging_bucket_id" { value = aws_s3_bucket.staging.id }