data "archive_file" "detectora" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/detectora"
  output_path = "${path.module}/detectora.zip"
}

data "archive_file" "descarga" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src/descarga"
  output_path = "${path.module}/descarga.zip"
}

resource "aws_lambda_function" "detectora" {
  function_name    = "${var.project_name}-detectora"
  role             = var.detectora_role_arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.detectora.output_path
  source_code_hash = data.archive_file.detectora.output_base64sha256
  timeout          = var.lambda_detectora_timeout
  memory_size      = 256

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      ROW_BUCKET               = var.row_bucket_name
      QUEUE_URL                = var.periodos_faltantes_queue_url
      TLC_BASE_URL             = var.tlc_base_url
      FORMATOS                 = join(",", var.formatos)
      FECHA_INICIO             = var.fecha_inicio
      FECHA_INICIO_POR_FORMATO = jsonencode(var.fecha_inicio_por_formato)
    }
  }
}

resource "aws_lambda_function" "descarga" {
  function_name    = "${var.project_name}-descarga"
  role             = var.descarga_role_arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.descarga.output_path
  source_code_hash = data.archive_file.descarga.output_base64sha256
  timeout          = var.lambda_descarga_timeout
  memory_size      = var.lambda_descarga_memory

  tracing_config {
    mode = "Active"
  }

  ephemeral_storage {
    size = 2048
  }

  environment {
    variables = {
      ROW_BUCKET    = var.row_bucket_name
      GLUE_JOB_NAME = var.glue_job_name
    }
  }
}


resource "aws_lambda_event_source_mapping" "periodos_faltantes" {
  event_source_arn = var.periodos_faltantes_queue_arn
  function_name    = aws_lambda_function.descarga.arn
  batch_size       = 1

  scaling_config {
    maximum_concurrency = 5
  }
}
