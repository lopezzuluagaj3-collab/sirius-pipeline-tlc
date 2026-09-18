output "disparo_mensual_rule_name" {
  description = "Nombre de la regla mensual de EventBridge"
  value       = aws_cloudwatch_event_rule.disparo_mensual.name
}

output "disparo_mensual_rule_arn" {
  description = "ARN de la regla mensual de EventBridge"
  value       = aws_cloudwatch_event_rule.disparo_mensual.arn
}
