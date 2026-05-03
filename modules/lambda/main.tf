variable "prefix" { 
    type = string 
}
variable "function_name" { 
    type = string 
}
variable "handler" { 
    type = string 
}
variable "runtime" { 
    type = string
}
variable "memory_size" { 
    type = number 
}
variable "timeout" { 
    type = number 
}
variable "source_dir" { 
    type = string 
}
variable "role_arn" { 
    type = string 
}
variable "subnet_ids" { 
    type = list(string) 
}
variable "security_group_ids" { 
    type = list(string) 
}
variable "environment_variables" { 
    type = map(string) 
}
variable "layers" {
    type = list(string)
    default = []
}

data "archive_file" "lambda_zip" {
    type = "zip"
    source_dir = var.source_dir
    output_path = "${path.module}/../../.build/${var.prefix}-${var.function_name}.zip"
}

resource "aws_lambda_function" "this" {
    function_name = "${var.prefix}-${var.function_name}"
    role = var.role_arn
    handler = var.handler
    runtime = var.runtime
    memory_size = var.memory_size
    timeout = var.timeout
    filename = data.archive_file.lambda_zip.output_path
    source_code_hash = data.archive_file.lambda_zip.output_base64sha256
    layers = var.layers

    vpc_config {
        subnet_ids = var.subnet_ids
        security_group_ids = var.security_group_ids
    }

    environment {
        variables = var.environment_variables
    }

    tags = { 
        Name = "${var.prefix}-${var.function_name}" 
    }
}

output "function_arn" { 
    value = aws_lambda_function.this.arn 
}
output "function_name" { 
    value = aws_lambda_function.this.function_name 
}
output "invoke_arn"    { 
    value = aws_lambda_function.this.invoke_arn 
}