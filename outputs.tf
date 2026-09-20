output "row_bucket_name" {
  description = "Nombre del bucket S3 de la zona row"
  value       = module.s3.row_bucket_name
}

output "row_bucket_arn" {
  description = "ARN del bucket S3 de la zona row"
  value       = module.s3.row_bucket_arn
}

output "logs_bucket_name" {
  description = "Nombre del bucket de logs de acceso S3"
  value       = module.s3.logs_bucket_name
}

output "periodos_faltantes_queue_url" {
  description = "URL de la cola SQS de periodos faltantes"
  value       = module.sqs.periodos_faltantes_queue_url
}

output "periodos_faltantes_queue_arn" {
  description = "ARN de la cola SQS de periodos faltantes"
  value       = module.sqs.periodos_faltantes_queue_arn
}

output "periodos_faltantes_dlq_url" {
  description = "URL de la Dead Letter Queue de periodos faltantes"
  value       = module.sqs.periodos_faltantes_dlq_url
}

output "periodos_faltantes_dlq_arn" {
  description = "ARN de la Dead Letter Queue de periodos faltantes"
  value       = module.sqs.periodos_faltantes_dlq_arn
}

output "lambda_detectora_name" {
  description = "Nombre de la funcion Lambda detectora"
  value       = module.lambda.lambda_detectora_name
}

output "lambda_descarga_name" {
  description = "Nombre de la funcion Lambda de descarga"
  value       = module.lambda.lambda_descarga_name
}

output "lambda_detectora_arn" {
  description = "ARN de la funcion Lambda detectora"
  value       = module.lambda.lambda_detectora_arn
}

output "lambda_descarga_arn" {
  description = "ARN de la funcion Lambda de descarga"
  value       = module.lambda.lambda_descarga_arn
}

output "disparo_mensual_rule_name" {
  description = "Nombre de la regla mensual de EventBridge"
  value       = module.eventbridge.disparo_mensual_rule_name
}

output "disparo_mensual_rule_arn" {
  description = "ARN de la regla mensual de EventBridge"
  value       = module.eventbridge.disparo_mensual_rule_arn
}

output "powerbi_reader_access_key_id" {
  description = "Access Key ID para conexion de Power BI a Athena"
  value       = module.iam.powerbi_reader_access_key_id
}

output "powerbi_reader_secret_access_key" {
  description = "Secret Access Key para conexion de Power BI a Athena"
  value       = module.iam.powerbi_reader_secret_access_key
  sensitive   = true
}

output "mart_bucket_name" {
  description = "Nombre del bucket S3 de la zona mart"
  value       = module.s3.mart_bucket_name
}

output "mart_bucket_arn" {
  description = "ARN del bucket S3 de la zona mart"
  value       = module.s3.mart_bucket_arn
}

output "glue_database_name" {
  description = "Nombre de la base de datos de Glue Catalog en la capa row"
  value       = module.athena.database_name
}

output "athena_workgroup_name" {
  description = "Nombre del Workgroup de Athena para EDA"
  value       = module.athena.workgroup_name
}

output "staging_bucket_name" {
  description = "Nombre del bucket S3 de la zona staging"
  value       = module.s3.staging_bucket_name
}

output "staging_bucket_arn" {
  description = "ARN del bucket S3 de la zona staging"
  value       = module.s3.staging_bucket_arn
}

output "glue_job_name" {
  description = "Nombre del AWS Glue Job de limpieza"
  value       = module.glue.glue_job_name
}

