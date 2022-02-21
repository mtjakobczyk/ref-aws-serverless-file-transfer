
output "client_vpc_endpoints" { value = aws_vpc_endpoint.file_transfer_service.id }
output "staging_bucket_arn" { value = aws_s3_bucket.staging.arn }
output "staging_bucket_id" { value = aws_s3_bucket.staging.id }
output "dynamodb_table_file_transfers_name" { value = aws_dynamodb_table.file_transfers.id } # arn, id == name
output "execution_role_arn" { value = aws_iam_role.file_transfer_requester.arn }