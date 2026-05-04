# =============================================================================
# Image Processor — Main Configuration
# Desplegable en 3 entornos: dev, qa, prod
# =============================================================================

terraform {
    required_version = ">= 1.5.0"
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
        random = {
            source  = "hashicorp/random"
            version = "~> 3.0"
        }
    }
}

provider "aws" {
    region = var.aws_region

    default_tags {
        tags = {
            Project     = "procesador-imagenes"
            Environment = var.environment
            ManagedBy   = "terraform"
        }
    }
}

# configuración de variables

variable "aws_region" {
    description = "Region de AWS"
    type = string
    default = "us-east-1"
}

variable "environment" {
    description = "Entorno de despliegue: dev, qa, prod"
    type = string
    default = "dev"

    validation {
        condition = contains(["dev", "qa", "prod"], var.environment)
        error_message = "El entorno debe ser: dev, qa o prod."
    }
}

variable "project_name" {
    description = "Nombre del proyecto"
    type = string
    default = "procesador-imagenes"
}

locals {
    prefix = "${var.project_name}-${var.environment}"
}

# configuración de módulos 
module "vpc" {
    source = "./modules/vpc"
    prefix = local.prefix
    aws_region = var.aws_region
}

module "s3" {
    source = "./modules/s3"
    prefix = local.prefix
    environment = var.environment
}

module "sqs" {
    source = "./modules/sqs"
    prefix = local.prefix
    s3_bucket_arn = module.s3.bucket_arn
    s3_bucket_id = module.s3.bucket_id
}

module "iam" {
    source = "./modules/iam"
    prefix = local.prefix
    s3_bucket_arn = module.s3.bucket_arn
    sqs_queue_arn = module.sqs.queue_arn
    aws_region = var.aws_region
}

module "lambda_upload" {
    source = "./modules/lambda"
    prefix = local.prefix
    function_name = "upload"
    handler = "index.handler"
    runtime = "python3.12"
    memory_size = 256
    timeout = 30
    source_dir = "${path.module}/lambdas/upload"
    role_arn = module.iam.upload_role_arn
    subnet_ids = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.upload_sg_id]

    environment_variables = {
        S3_BUCKET = module.s3.bucket_id
        UPLOAD_PREFIX = "uploads/"
    }
}

module "lambda_crop" {
    source = "./modules/lambda"
    prefix = local.prefix
    function_name = "crop"
    handler = "index.handler"
    runtime = "python3.12"
    memory_size = 512
    timeout = 60
    source_dir = "${path.module}/lambdas/crop"
    role_arn = module.iam.crop_role_arn
    subnet_ids = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.crop_sg_id]
    layers = ["arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p312-Pillow:11"]

    environment_variables = {
        S3_BUCKET = module.s3.bucket_id
        PROCESSED_PREFIX = "processed/"
    }
}

# Configuración de eventos
resource "aws_lambda_event_source_mapping" "sqs_to_crop" {
    event_source_arn = module.sqs.queue_arn
    function_name = module.lambda_crop.function_arn
    batch_size = 5
    function_response_types = ["ReportBatchItemFailures"]
    enabled = true
}

module "apigateway" {
    source = "./modules/apigateway"
    prefix = local.prefix
    upload_lambda_arn = module.lambda_upload.function_arn
    upload_lambda_name = module.lambda_upload.function_name
}

module "monitoring" {
    source = "./modules/monitoring"
    prefix = local.prefix
    upload_lambda_name = module.lambda_upload.function_name
    crop_lambda_name = module.lambda_crop.function_name
    api_id = module.apigateway.api_id
    api_name = module.apigateway.api_name
    dlq_name = module.sqs.dlq_name
}

# Configuración de outputs 
output "api_endpoint" {
    description = "URL del API Gateway para subir imagenes"
    value = module.apigateway.api_endpoint
}

output "s3_bucket" {
    description = "Nombre del bucket S3"
    value = module.s3.bucket_id
}

output "environment" {
    description = "Entorno actual"
    value = var.environment
}