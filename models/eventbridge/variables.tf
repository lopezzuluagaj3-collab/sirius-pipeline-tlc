variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo de recursos EventBridge"
  type        = string
}

variable "schedule_expression" {
  description = "Expresion cron de EventBridge para el disparo de la Lambda detectora"
  type        = string
}

variable "lambda_function_name" {
  description = "Nombre de la Lambda detectora invocada por EventBridge"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN de la Lambda detectora invocada por EventBridge"
  type        = string
}
