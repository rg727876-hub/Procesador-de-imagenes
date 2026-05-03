variable "prefix" { 
    type = string 
}

variable "upload_lambda_arn" {
    type = string 
}

variable "upload_lambda_name" { 
    type = string 
}

resource "aws_apigatewayv2_api" "api" {
    name = "${var.prefix}-api"
    protocol_type = "HTTP"

    cors_configuration {
        allow_origins = ["*"]
        allow_methods = ["POST", "OPTIONS"]
        allow_headers = ["Content-Type"]
        max_age       = 3600
    }

    tags = { 
        Name = "${var.prefix}-api" 
    }
}

resource "aws_apigatewayv2_stage" "default" {
    api_id      = aws_apigatewayv2_api.api.id
    name        = "$default"
    auto_deploy = true

    access_log_settings {
        destination_arn = aws_cloudwatch_log_group.api.arn
        format = jsonencode({
            requestId = "$context.requestId"
            ip = "$context.identity.sourceIp"
            requestTime = "$context.requestTime"
            httpMethod = "$context.httpMethod"
            routeKey = "$context.routeKey"
            status = "$context.status"
            protocol = "$context.protocol"
            responseLength = "$context.responseLength"
        })
    }
}

resource "aws_cloudwatch_log_group" "api" {
    name = "/aws/apigateway/${var.prefix}-api"
    retention_in_days = 14
}

resource "aws_apigatewayv2_integration" "upload" {
    api_id = aws_apigatewayv2_api.api.id
    integration_type = "AWS_PROXY"
    integration_uri = var.upload_lambda_arn
    payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "upload" {
    api_id = aws_apigatewayv2_api.api.id
    route_key = "POST /upload"
    target = "integrations/${aws_apigatewayv2_integration.upload.id}"
}

resource "aws_lambda_permission" "apigw" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = var.upload_lambda_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

output "api_endpoint" { 
    value = aws_apigatewayv2_api.api.api_endpoint 
}
output "api_id" { 
    value = aws_apigatewayv2_api.api.id 
}
output "api_name" { 
    value = aws_apigatewayv2_api.api.name 
}
