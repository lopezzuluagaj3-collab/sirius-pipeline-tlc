output "database_name" {
  description = "Nombre de la base de datos de Glue Catalog en la capa row"
  value       = aws_glue_catalog_database.row.name
}

output "workgroup_name" {
  description = "Nombre del Workgroup de Athena para EDA"
  value       = aws_athena_workgroup.eda.name
}

output "workgroup_arn" {
  description = "ARN del Workgroup de Athena para EDA"
  value       = aws_athena_workgroup.eda.arn
}
