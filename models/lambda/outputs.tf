output "lambda_detectora_name" {
  description = "Nombre de la funcion Lambda detectora"
  value       = aws_lambda_function.detectora.function_name
}

output "lambda_detectora_arn" {
  description = "ARN de la funcion Lambda detectora"
  value       = aws_lambda_function.detectora.arn
}

output "lambda_descarga_name" {
  description = "Nombre de la funcion Lambda de descarga"
  value       = aws_lambda_function.descarga.function_name
}

output "lambda_descarga_arn" {
  description = "ARN de la funcion Lambda de descarga"
  value       = aws_lambda_function.descarga.arn
}
