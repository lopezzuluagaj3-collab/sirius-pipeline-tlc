output "row_bucket_name" {
  description = "Nombre del bucket S3 de la zona row"
  value       = aws_s3_bucket.row.bucket
}

output "row_bucket_arn" {
  description = "ARN del bucket S3 de la zona row"
  value       = aws_s3_bucket.row.arn
}

output "logs_bucket_name" {
  description = "Nombre del bucket de logs de acceso S3"
  value       = aws_s3_bucket.logs.bucket
}

output "logs_bucket_arn" {
  description = "ARN del bucket de logs de acceso S3"
  value       = aws_s3_bucket.logs.arn
}
