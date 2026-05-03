variable "prefix"{ 
    type = string 
}
variable "s3_bucket_arn" { 
    type = string 
}
variable "sqs_queue_arn" { 
    type = string 
}
variable "aws_region" { 
    type = string 
}

data "aws_iam_policy_document" "lambda_assume" {
    statement {
        actions = ["sts:AssumeRole"]
        principals {
            type        = "Service"
            identifiers = ["lambda.amazonaws.com"]
        }
    }
}

# creación de roles y políticas para las lambdas

resource "aws_iam_role" "upload" {
    name = "${var.prefix}-upload-lambda-role"
    assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "upload_basic" {
    role = aws_iam_role.upload.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "upload_vpc" {
    role = aws_iam_role.upload.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "upload_s3" {
    name = "${var.prefix}-upload-s3-policy"
    role = aws_iam_role.upload.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect   = "Allow"
            Action   = ["s3:PutObject"]
            Resource = "${var.s3_bucket_arn}/uploads/*"
        }]
    })
}

# creación de roles y políticas para la lambda de recorte

resource "aws_iam_role" "crop" {
    name = "${var.prefix}-crop-lambda-role"
    assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "crop_basic" {
    role = aws_iam_role.crop.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "crop_vpc" {
    role = aws_iam_role.crop.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "crop_s3" {
    name = "${var.prefix}-crop-s3-policy"
    role = aws_iam_role.crop.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = ["s3:GetObject"]
                Resource = "${var.s3_bucket_arn}/uploads/*"
            },
            {
                Effect = "Allow"
                Action = ["s3:PutObject"]
                Resource = "${var.s3_bucket_arn}/processed/*"
            }
        ]
    })
}

resource "aws_iam_role_policy" "crop_sqs" {
    name = "${var.prefix}-crop-sqs-policy"
    role = aws_iam_role.crop.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
            "sqs:ChangeMessageVisibility"
            ]
            Resource = var.sqs_queue_arn
        }]
    })
}

output "upload_role_arn" { 
    value = aws_iam_role.upload.arn 
    }
output "crop_role_arn" { 
    value = aws_iam_role.crop.arn 
}