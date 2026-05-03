variable "prefix" {
    type = string
}

variable "aws_region" {
    type = string
}

data "aws_availability_zones" "available" {
    state = "available"
}

# creación de VPC
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        name = "${var.prefix}-vpc"
    }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "${var.prefix}-igw"
    }
}

# Subnet públicas para NAT gateway
resource "aws_subnet" "public_a" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    availability_zone = data.aws_availability_zones.available.names[0]
    tags = {
        Name = "${var.prefix}-public_a"
    }
}

resource "aws_subnet" "public_b" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.2.0/24"
    availability_zone = data.aws_availability_zones.available.names[1]
    tags = {
        Name = "${var.prefix}-public_b"
    }
}

# Subnet privadas para Lambdas
resource "aws_subnet" "private_a" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.11.0/24"
    availability_zone = data.aws_availability_zones.available.names[0]
    tags = { 
        Name = "${var.prefix}-private-a" 
    }
}

resource "aws_subnet" "private_b" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.12.0/24"
    availability_zone = data.aws_availability_zones.available.names[1]
    tags = { 
        Name = "${var.prefix}-private-b" 
    }
}

# NAT Gateways
resource "aws_eip" "nat_a" {
    domain = "vpc"
    tags = { 
        Name = "${var.prefix}-nat-eip-a" 
    }
}

resource "aws_eip" "nat_b" {
    domain = "vpc"
    tags = { 
        Name = "${var.prefix}-nat-eip-b" 
    }
}

resource "aws_nat_gateway" "nat_a" {
    allocation_id = aws_eip.nat_a.id
    subnet_id = aws_subnet.public_a.id
    tags = { 
        Name = "${var.prefix}-nat-a" 
    }
}

resource "aws_nat_gateway" "nat_b" {
    allocation_id = aws_eip.nat_b.id
    subnet_id = aws_subnet.public_b.id
    tags = { 
        Name = "${var.prefix}-nat-b" 
    }
}

# creación de Route Tables y asociaciones

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id
    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
    }
    tags = { 
        Name = "${var.prefix}-rt-public" 
    }
}

resource "aws_route_table_association" "public_a" {
    subnet_id = aws_subnet.public_a.id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
    subnet_id = aws_subnet.public_b.id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_a" {
    vpc_id = aws_vpc.main.id
    route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
    }
    tags = { 
        Name = "${var.prefix}-rt-private-a" 
    }
}

resource "aws_route_table_association" "private_a" {
    subnet_id = aws_subnet.private_a.id
    route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table" "private_b" {
    vpc_id = aws_vpc.main.id
    route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
    }
    tags = { 
        Name = "${var.prefix}-rt-private-b" 
    }
}

resource "aws_route_table_association" "private_b" {
    subnet_id = aws_subnet.private_b.id
    route_table_id = aws_route_table.private_b.id
}

# Creación de VPC Endpoints para S3 (Gateway) y SQS (Interface)

resource "aws_vpc_endpoint" "s3" {
    vpc_id = aws_vpc.main.id
    service_name = "com.amazonaws.${var.aws_region}.s3"
    vpc_endpoint_type = "Gateway"
    route_table_ids = [
        aws_route_table.private_a.id,
        aws_route_table.private_b.id,
    ]
    tags = { 
        Name = "${var.prefix}-vpce-s3" 
    }
}

resource "aws_vpc_endpoint" "sqs" {
    vpc_id = aws_vpc.main.id
    service_name = "com.amazonaws.${var.aws_region}.sqs"
    vpc_endpoint_type = "Interface"
    private_dns_enabled = true
    subnet_ids = [
        aws_subnet.private_a.id,
        aws_subnet.private_b.id,
    ]
    security_group_ids = [aws_security_group.vpce_sqs.id]
    tags = { 
        Name = "${var.prefix}-vpce-sqs" 
    }
}

# creación de Security Groups para Lambdas y VPC Endpoints

resource "aws_security_group" "upload_lambda" {
    name_prefix = "${var.prefix}-sg-upload-"
    vpc_id = aws_vpc.main.id
    description = "SG para upload Lambda"

    egress {
        from_port = 443
        to_port = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTPS salida"
    }

    tags = { 
        Name = "${var.prefix}-sg-upload-lambda" 
    }
    lifecycle { 
        create_before_destroy = true 
    }
}

resource "aws_security_group" "crop_lambda" {
    name_prefix = "${var.prefix}-sg-crop-"
    vpc_id = aws_vpc.main.id
    description = "SG para crop Lambda"

    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTPS salida"
    }

    tags = { 
        Name = "${var.prefix}-sg-crop-lambda" 
    }
    lifecycle { 
        create_before_destroy = true 
    }
}

resource "aws_security_group" "vpce_sqs" {
    name_prefix = "${var.prefix}-sg-vpce-sqs-"
    vpc_id      = aws_vpc.main.id
    description = "SG para SQS VPC Endpoint"

    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        security_groups = [
            aws_security_group.upload_lambda.id,
            aws_security_group.crop_lambda.id,
        ]
    description = "HTTPS desde Lambdas"
    }

    tags = { 
        Name = "${var.prefix}-sg-vpce-sqs" 
    }
    lifecycle { 
        create_before_destroy = true 
    }
}

# Outputs para usar en otros módulos

output "vpc_id" { 
    value = aws_vpc.main.id 
}
output "private_subnet_ids" { 
    value = [
        aws_subnet.private_a.id, 
        aws_subnet.private_b.id
    ] 
}
output "public_subnet_ids" { 
    value = [
        aws_subnet.public_a.id, 
        aws_subnet.public_b.id
    ]
}
output "upload_sg_id" { 
    value = aws_security_group.upload_lambda.id 
}
output "crop_sg_id" { 
    value = aws_security_group.crop_lambda.id 
}