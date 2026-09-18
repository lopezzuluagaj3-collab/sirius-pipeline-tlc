variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo de recursos"
  type        = string
  default     = "sirius"
}


variable "environment" {
  description = "Entorno de despliegue (dev, prod, etc.)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Región de AWS donde se despliega la infraestructura"
  type        = string
  default     = "us-east-2"
}

variable "formatos" {
  description = "Formatos de datos NYC TLC a procesar"
  type        = list(string)
  default     = ["yellow", "green", "fhv", "fhvhv"]
}

variable "fecha_inicio" {
  description = "Periodo mas antiguo por defecto a considerar, formato YYYY-MM"
  type        = string
  default     = "2015-01"
}

variable "fecha_inicio_por_formato" {
  description = "Periodo mas antiguo a considerar por formato, formato YYYY-MM"
  type        = map(string)
  default = {
    yellow = "2009-01"
    green  = "2013-08"
    fhv    = "2015-01"
    fhvhv  = "2019-02"
  }
}

variable "tlc_base_url" {
  description = "URL base del CDN oficial de NYC TLC donde viven los Parquet"
  type        = string
  default     = "https://d37ci6vzurychx.cloudfront.net/trip-data"
}

variable "schedule_expression" {
  description = "Expresion cron de EventBridge para el disparo de la Lambda detectora"
  type        = string
  default     = "cron(0 6 1 * ? *)" # día 1 de cada mes, 6am UTC
}

variable "lambda_detectora_timeout" {
  description = "Timeout en segundos de la Lambda detectora"
  type        = number
  default     = 300
}

variable "lambda_descarga_timeout" {
  description = "Timeout en segundos de la Lambda de descarga"
  type        = number
  default     = 600
}

variable "lambda_descarga_memory" {
  description = "Memoria en MB de la Lambda de descarga (afecta tambien /tmp y CPU)"
  type        = number
  default     = 1024
}

variable "sqs_max_receive_count" {
  description = "Intentos antes de mandar un mensaje a la Dead Letter Queue"
  type        = number
  default     = 3
}
