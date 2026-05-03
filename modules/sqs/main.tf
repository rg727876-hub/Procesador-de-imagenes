variable "prefix" { 
    type = string 
}
variable "s3_bucket_arn" { 
    type = string 
}
variable "s3_bucket_id" { 
    type = string 
}

resource "aws_sqs_queue" "dlq" {
    name = "${var.prefix}-image-dlq"
    message_retention_seconds = 1209600
    tags = { 
        Name = "${var.prefix}-image-dlq" 
    }
}

resource "aws_sqs_queue" "main" {
    name = "${var.prefix}-image-queue"
    visibility_timeout_seconds = 360
    message_retention_seconds = 86400
    receive_wait_time_seconds = 20

    redrive_policy = jsonencode({
        deadLetterTargetArn = aws_sqs_queue.dlq.arn
        maxReceiveCount = 3
    })

    tags = { 
        Name = "${var.prefix}-image-queue" 
    }
}

resource "aws_sqs_queue_policy" "s3_notify" {
    queue_url = aws_sqs_queue.main.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Principal = { 
                Service = "s3.amazonaws.com" 
            }
            Action = "sqs:SendMessage"
            Resource = aws_sqs_queue.main.arn
            Condition = {
                ArnEquals = { 
                    "aws:SourceArn" = var.s3_bucket_arn
                }
            }
        }]
    })
}

resource "aws_s3_bucket_notification" "image_uploaded" {
    bucket = var.s3_bucket_id

    queue {
        queue_arn = aws_sqs_queue.main.arn
        events = ["s3:ObjectCreated:*"]
        filter_prefix = "uploads/"
    }

    depends_on = [
        aws_sqs_queue_policy.s3_notify
    ]
}

output "queue_arn" { 
    value = aws_sqs_queue.main.arn 
}
output "queue_url" { 
    value = aws_sqs_queue.main.url 
}
output "queue_name" { 
    value = aws_sqs_queue.main.name 
}
output "dlq_arn"    { 
    value = aws_sqs_queue.dlq.arn 
}
output "dlq_name"   { 
    value = aws_sqs_queue.dlq.name 
}