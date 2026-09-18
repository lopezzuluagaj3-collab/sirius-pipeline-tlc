variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo de funciones Lambda"
  type        = string
}

variable "row_bucket_name" {
  description = "Nombre del bucket row usado por ambas Lambdas"
  type        = string
}

variable "periodos_faltantes_queue_url" {
  description = "URL de la cola SQS donde la detectora encola periodos faltantes"
  type        = string
}

variable "periodos_faltantes_queue_arn" {
  description = "ARN de la cola SQS que dispara la Lambda de descarga"
  type        = string
}

variable "detectora_role_arn" {
  description = "ARN del rol IAM usado por la Lambda detectora"
  type        = string
}

variable "descarga_role_arn" {
  description = "ARN del rol IAM usado por la Lambda de descarga"
  type        = string
}

variable "formatos" {
  description = "Formatos de datos NYC TLC a procesar"
  type        = list(string)
}

variable "fecha_inicio" {
  description = "Periodo mas antiguo por defecto a considerar, formato YYYY-MM"
  type        = string
}

variable "fecha_inicio_por_formato" {
  description = "Periodo mas antiguo a considerar por formato, formato YYYY-MM"
  type        = map(string)
}

variable "tlc_base_url" {
  description = "URL base del CDN oficial de NYC TLC donde viven los Parquet"
  type        = string
}

variable "lambda_detectora_timeout" {
  description = "Timeout en segundos de la Lambda detectora"
  type        = number
}

variable "lambda_descarga_timeout" {
  description = "Timeout en segundos de la Lambda de descarga"
  type        = number
}

variable "lambda_descarga_memory" {
  description = "Memoria en MB de la Lambda de descarga"
  type        = number
}
