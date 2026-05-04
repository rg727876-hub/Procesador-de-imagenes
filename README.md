# Procesador de Imágenes — AWS Serverless con Terraform

Sistema serverless que recibe una imagen, la almacena en S3 y automáticamente la recorta en un avatar circular de 40x40 px.

## Arquitectura

```
Cliente --> API Gateway --> Upload Lambda --> S3 (uploads/)
                                                 |
                                          S3 Event --> SQS
                                                 |
                                          Crop Lambda --> S3 (processed/)
```

## Componentes

- **API Gateway HTTP v2** — recibe POST /upload (base64 o binario)
- **Upload Lambda (Python 3.12)** — valida y sube la imagen a S3
- **S3 Bucket** — almacena originales en `uploads/` y procesadas en `processed/`
- **SQS** — cola de mensajes con DLQ (3 reintentos)
- **Crop Lambda (Python 3.12 + Pillow)** — recorta imagen en circulo 40x40 px
- **VPC** — red privada con 2 AZs, NAT Gateways y VPC Endpoints
- **CloudWatch** — logs y alarma en DLQ

## Requisitos

- AWS CLI configurado (`aws configure`)
- Terraform >= 1.5.0

## Despliegue

```bash
terraform init

# DEV
terraform workspace new dev
terraform apply -var-file="envs/dev.tfvars"

# QA
terraform workspace new qa
terraform apply -var-file="envs/qa.tfvars"

# PROD
terraform workspace new prod
terraform apply -var-file="envs/prod.tfvars"
```

## Prueba

```bash
# PowerShell
$bytes = [System.IO.File]::ReadAllBytes('foto.jpg')
Invoke-RestMethod -Uri "https://API_URL/upload" -Method POST -ContentType "image/jpeg" -Body $bytes

# curl
curl -X POST https://API_URL/upload -H "Content-Type: image/jpeg" --data-binary @foto.jpg
```

## Destruir

```bash
terraform workspace select prod
terraform destroy -var-file="envs/prod.tfvars"

terraform workspace select qa
terraform destroy -var-file="envs/qa.tfvars"

terraform workspace select dev
terraform destroy -var-file="envs/dev.tfvars"
```