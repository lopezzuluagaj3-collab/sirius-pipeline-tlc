output "periodos_faltantes_queue_url" {
  description = "URL de la cola SQS de periodos faltantes"
  value       = aws_sqs_queue.periodos_faltantes.url
}

output "periodos_faltantes_queue_arn" {
  description = "ARN de la cola SQS de periodos faltantes"
  value       = aws_sqs_queue.periodos_faltantes.arn
}

output "periodos_faltantes_dlq_url" {
  description = "URL de la Dead Letter Queue de periodos faltantes"
  value       = aws_sqs_queue.periodos_faltantes_dlq.url
}

output "periodos_faltantes_dlq_arn" {
  description = "ARN de la Dead Letter Queue de periodos faltantes"
  value       = aws_sqs_queue.periodos_faltantes_dlq.arn
}
