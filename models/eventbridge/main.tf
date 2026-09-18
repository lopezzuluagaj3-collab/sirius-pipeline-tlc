resource "aws_cloudwatch_event_rule" "disparo_mensual" {
  name                = "${var.project_name}-disparo-mensual-detectora"
  description         = "Dispara la Lambda detectora una vez al mes"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "detectora" {
  rule      = aws_cloudwatch_event_rule.disparo_mensual.name
  target_id = "lambda-detectora"
  arn       = var.lambda_function_arn
}

resource "aws_lambda_permission" "permitir_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.disparo_mensual.arn
}
