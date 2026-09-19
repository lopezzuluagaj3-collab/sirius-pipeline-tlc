resource "aws_sqs_queue" "periodos_faltantes_dlq" {
  name                      = "${var.project_name}-periodos-faltantes-dlq"
  message_retention_seconds = 1209600 # 14 dias, para poder inspeccionar y reprocesar
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "periodos_faltantes" {
  name                       = "${var.project_name}-periodos-faltantes"
  visibility_timeout_seconds = var.lambda_descarga_timeout * 2
  message_retention_seconds  = 345600 # 4 dias
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.periodos_faltantes_dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "periodos_faltantes_dlq" {
  queue_url = aws_sqs_queue.periodos_faltantes_dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.periodos_faltantes.arn]
  })
}
