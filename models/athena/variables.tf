variable "project_name" {
  description = "Nombre base del proyecto"
  type        = string
}

variable "row_bucket_name" {
  description = "Nombre del bucket S3 de la zona row"
  type        = string
}

variable "mart_bucket_name" {
  description = "Nombre del bucket S3 de la zona mart"
  type        = string
}

variable "staging_bucket_name" {
  description = "Nombre del bucket S3 de la zona staging"
  type        = string
}
