variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo de roles IAM"
  type        = string
}

variable "aws_region" {
  description = "Region de AWS usada para acotar permisos de logs"
  type        = string
}

variable "row_bucket_arn" {
  description = "ARN del bucket row que consumen las politicas IAM"
  type        = string
}

variable "periodos_faltantes_queue_arn" {
  description = "ARN de la cola SQS de periodos faltantes que consumen las politicas IAM"
  type        = string
}
