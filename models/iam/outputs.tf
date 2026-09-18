output "detectora_role_arn" {
  description = "ARN del rol IAM de la Lambda detectora"
  value       = aws_iam_role.detectora.arn
}

output "descarga_role_arn" {
  description = "ARN del rol IAM de la Lambda de descarga"
  value       = aws_iam_role.descarga.arn
}
