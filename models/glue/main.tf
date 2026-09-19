data "aws_caller_identity" "current" {}

# ---------- Rol IAM para AWS Glue ----------

data "aws_iam_policy_document" "glue_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_job" {
  name               = "${var.project_name}-glue-job-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role.json
}

data "aws_iam_policy_document" "glue_job" {
  # Lectura en bucket row (origen)
  statement {
    sid     = "ReadRowBucket"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      var.row_bucket_arn,
      "${var.row_bucket_arn}/*"
    ]
  }

  # Lectura y escritura en bucket staging (destino y scripts)
  statement {
    sid = "ReadWriteStagingBucket"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      var.staging_bucket_arn,
      "${var.staging_bucket_arn}/*"
    ]
  }

  # Logs continuos y métricas en CloudWatch
  statement {
    sid = "GlueCloudWatchLogsAndMetrics"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:AssociateKmsKey",
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
  }

}

resource "aws_iam_role_policy" "glue_job" {
  name   = "${var.project_name}-glue-job-policy"
  role   = aws_iam_role.glue_job.id
  policy = data.aws_iam_policy_document.glue_job.json
}

# Subir el script PySpark al bucket staging
resource "aws_s3_object" "glue_script" {
  bucket = var.staging_bucket_name
  key    = "scripts/job_limpieza_staging.py"
  source = "${path.module}/scripts/job_limpieza_staging.py"
  etag   = filemd5("${path.module}/scripts/job_limpieza_staging.py")
}

# ---------- Recurso AWS Glue Job ----------

resource "aws_glue_job" "limpieza" {
  name              = "${var.project_name}-limpieza-staging"
  role_arn          = aws_iam_role.glue_job.arn
  glue_version      = var.glue_version
  worker_type       = var.worker_type
  number_of_workers = var.number_of_workers
  timeout           = var.job_timeout

  command {
    name            = "glueetl"
    script_location = "s3://${var.staging_bucket_name}/${aws_s3_object.glue_script.key}"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--continuous-log-logGroup"          = "/aws-glue/jobs/${var.project_name}-limpieza-staging"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--enable-metrics"                   = "true"
    "--enable-auto-scaling"              = "false"
    "--ROW_BUCKET"                       = var.row_bucket_name
    "--STAGING_BUCKET"                   = var.staging_bucket_name
  }
}
