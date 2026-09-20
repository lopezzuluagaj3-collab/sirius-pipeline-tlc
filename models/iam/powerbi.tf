# =============================================================
# USUARIO IAM DE SOLO LECTURA PARA POWER BI (PRINCIPIO DE MINIMO PRIVILEGIO)
# =============================================================

resource "aws_iam_user" "powerbi_reader" {
  name = "${var.project_name}-powerbi-reader"

  tags = {
    Description = "Usuario con permisos de solo lectura para conectar Power BI con Athena y la Capa Mart"
  }
}

resource "aws_iam_access_key" "powerbi_reader" {
  user = aws_iam_user.powerbi_reader.name
}

data "aws_iam_policy_document" "powerbi_reader" {
  # 1. Permisos en Athena: ejecutar consultas en el workgroup de EDA / Analytics
  statement {
    sid = "AthenaQueryExecution"
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:StopQueryExecution",
      "athena:GetWorkGroup"
    ]
    resources = [
      var.athena_workgroup_arn
    ]
  }

  statement {
    sid = "AthenaListOperations"
    actions = [
      "athena:ListWorkGroups",
      "athena:ListDataCatalogs",
      "athena:ListDatabases",
      "athena:ListTableMetadata",
      "athena:GetDatabase",
      "athena:GetTableMetadata"
    ]
    resources = ["*"]
  }

  # 2. Permisos en Glue Data Catalog: solo lectura sobre la capa Mart y catálogo
  statement {
    sid = "GlueCatalogReadOnly"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartitions"
    ]
    resources = [
      "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:database/${var.project_name}_mart_db",
      "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}_mart_db/*"
    ]
  }

  # 3. Permisos en S3:
  # - Lectura de los datos agregados en la capa mart
  # - Lectura y escritura de los resultados de consulta de Athena en result_eda/
  statement {
    sid = "S3MartDataReadOnly"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      var.mart_bucket_arn,
      "${var.mart_bucket_arn}/*"
    ]
  }

  statement {
    sid = "S3AthenaResultsReadWrite"
    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload"
    ]
    resources = [
      "${var.mart_bucket_arn}/result_eda/*"
    ]
  }
}

resource "aws_iam_user_policy" "powerbi_reader" {
  name   = "${var.project_name}-powerbi-reader-policy"
  user   = aws_iam_user.powerbi_reader.name
  policy = data.aws_iam_policy_document.powerbi_reader.json
}
