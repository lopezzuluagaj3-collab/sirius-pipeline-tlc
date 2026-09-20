output "detectora_role_arn" {
  description = "ARN del rol IAM de la Lambda detectora"
  value       = aws_iam_role.detectora.arn
}

output "descarga_role_arn" {
  description = "ARN del rol IAM de la Lambda de descarga"
  value       = aws_iam_role.descarga.arn
}

output "powerbi_reader_access_key_id" {
  description = "Access Key ID del usuario de solo lectura para Power BI"
  value       = aws_iam_access_key.powerbi_reader.id
}

output "powerbi_reader_secret_access_key" {
  description = "Secret Access Key del usuario de solo lectura para Power BI"
  value       = aws_iam_access_key.powerbi_reader.secret
  sensitive   = true
}
