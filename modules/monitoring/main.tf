variable "prefix" { 
    type = string 
}
variable "upload_lambda_name" { 
    type = string 
}
variable "crop_lambda_name" { 
    type = string 
}
variable "api_id" { 
    type = string 
}
variable "api_name" { 
    type = string 
}
variable "dlq_name" { 
    type = string 
}

resource "aws_cloudwatch_log_group" "upload_lambda" {
    name = "/aws/lambda/${var.upload_lambda_name}"
    retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "crop_lambda" {
    name = "/aws/lambda/${var.crop_lambda_name}"
    retention_in_days = 14
}

resource "aws_sns_topic" "alerts" {
    name = "${var.prefix}-alerts"
}

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
    alarm_name = "${var.prefix}-dlq-messages-alarm"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = 1
    metric_name = "ApproximateNumberOfMessagesVisible"
    namespace = "AWS/SQS"
    period  = 60
    statistic = "Sum"
    threshold = 0
    alarm_description = "Alarma cuando hay mensajes en la DLQ"
    alarm_actions = [aws_sns_topic.alerts.arn]

    dimensions = {
        QueueName = var.dlq_name
    }
}