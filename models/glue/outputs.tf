output "glue_job_name" {
  description = "Nombre del AWS Glue Job de limpieza"
  value       = aws_glue_job.limpieza.name
}

output "glue_job_arn" {
  description = "ARN del AWS Glue Job de limpieza"
  value       = aws_glue_job.limpieza.arn
}

output "glue_role_arn" {
  description = "ARN del rol IAM asignado al Glue Job"
  value       = aws_iam_role.glue_job.arn
}
