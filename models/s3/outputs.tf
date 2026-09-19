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

output "mart_bucket_name" {
  description = "Nombre del bucket S3 de la zona mart"
  value       = aws_s3_bucket.mart.bucket
}

output "mart_bucket_arn" {
  description = "ARN del bucket S3 de la zona mart"
  value       = aws_s3_bucket.mart.arn
}

output "staging_bucket_name" {
  description = "Nombre del bucket S3 de la zona staging"
  value       = aws_s3_bucket.staging.bucket
}

output "staging_bucket_arn" {
  description = "ARN del bucket S3 de la zona staging"
  value       = aws_s3_bucket.staging.arn
}

