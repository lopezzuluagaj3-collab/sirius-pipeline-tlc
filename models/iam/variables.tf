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

variable "github_org" {
  description = "Organizacion de GitHub duena del repositorio"
  type        = string
  default     = "lopezzuluagaj3-collab"
}

variable "github_repo" {
  description = "Nombre del repositorio de GitHub"
  type        = string
  default     = "sirius-pipeline-tlc"
}

variable "tfstate_bucket_name" {
  description = "Nombre del bucket S3 de estado remoto de Terraform"
  type        = string
  default     = "sirius-tfstate-603437461408"
}

variable "glue_job_arn" {
  description = "ARN del AWS Glue Job que puede disparar la Lambda de descarga"
  type        = string
  default     = ""
}

variable "mart_bucket_arn" {
  description = "ARN del bucket mart para lectura de Power BI"
  type        = string
  default     = ""
}

variable "athena_workgroup_arn" {
  description = "ARN del workgroup de Athena para consultas de Power BI"
  type        = string
  default     = ""
}

