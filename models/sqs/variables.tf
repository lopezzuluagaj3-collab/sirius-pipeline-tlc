variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo de recursos SQS"
  type        = string
}

variable "lambda_descarga_timeout" {
  description = "Timeout en segundos de la Lambda de descarga, usado para calcular el visibility timeout"
  type        = number
}

variable "sqs_max_receive_count" {
  description = "Intentos antes de mandar un mensaje a la Dead Letter Queue"
  type        = number
}
