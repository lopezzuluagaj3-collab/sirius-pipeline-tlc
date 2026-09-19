data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ---------- Lambda detectora ----------

resource "aws_iam_role" "detectora" {
  name               = "${var.project_name}-lambda-detectora"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "detectora" {
  statement {
    sid       = "ListRowBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.row_bucket_arn]
  }

  statement {
    sid       = "EnqueuePeriodosFaltantes"
    actions   = ["sqs:SendMessage"]
    resources = [var.periodos_faltantes_queue_arn]
  }

  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    sid = "XRay"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "detectora" {
  name   = "${var.project_name}-lambda-detectora-policy"
  role   = aws_iam_role.detectora.id
  policy = data.aws_iam_policy_document.detectora.json
}

# ---------- Lambda descarga ----------

resource "aws_iam_role" "descarga" {
  name               = "${var.project_name}-lambda-descarga"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "descarga" {
  statement {
    sid       = "PutRowObjects"
    actions   = ["s3:PutObject"]
    resources = ["${var.row_bucket_arn}/*"]
  }

  statement {
    sid = "ConsumePeriodosFaltantes"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [var.periodos_faltantes_queue_arn]
  }

  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    sid = "XRay"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "TriggerGlueJob"
    actions   = ["glue:StartJobRun"]
    resources = [var.glue_job_arn]
  }

}

resource "aws_iam_role_policy" "descarga" {
  name   = "${var.project_name}-lambda-descarga-policy"
  role   = aws_iam_role.descarga.id
  policy = data.aws_iam_policy_document.descarga.json
}
