variable "project_name" {
  description = "Nombre base del proyecto"
  type        = string
}

variable "aws_region" {
  description = "Región de AWS"
  type        = string
}

variable "row_bucket_name" {
  description = "Nombre del bucket S3 de la zona row"
  type        = string
}

variable "row_bucket_arn" {
  description = "ARN del bucket S3 de la zona row"
  type        = string
}

variable "staging_bucket_name" {
  description = "Nombre del bucket S3 de la zona staging"
  type        = string
}

variable "staging_bucket_arn" {
  description = "ARN del bucket S3 de la zona staging"
  type        = string
}

variable "glue_version" {
  description = "Versión de AWS Glue"
  type        = string
  default     = "4.0"
}

variable "worker_type" {
  description = "Tipo de worker para el Glue Job (G.1X, G.2X)"
  type        = string
  default     = "G.1X"
}

variable "number_of_workers" {
  description = "Número de workers asignados al Glue Job"
  type        = number
  default     = 2
}


variable "job_timeout" {
  description = "Timeout del Glue Job en minutos"
  type        = number
  default     = 60
}
