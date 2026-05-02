"""
upload lambda - Recibe la imagen (base64 o multipart) y la sube a s3 uploads/
Responsabilidad única: solo subir la imagen, nada más.
"""

import json
import os
import base64
import uuid
import boto3

s3_client = boto3.client('s3')
s3_BUCKET = os.environ['S3_BUCKET']
UPLOAD_PREFIX = os.environ.get("UPLOAD_PREFIX", "uploads/")

# Extenciones permitidas
ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png', 'gif', "webp"}
MAX_SIZE = 10 * 1024 * 1024  # 10MB

def handler(event, context):
    """
    Maneja POST /upload desde API Gateway HTTP API v2.
    acepta:
        - JSON con campo "image" en base64 y "filename"
        - Cuerpo binario (base 64-encoded por API Gateway) con Content-Type de imagen
    """
    try:
        content_type = event.get("headers", {}).get("Content-Type", "")

        # Si el Content-Type es JSON, esperamos un campo "image" con la imagen en base64 y un "filename"
        if "application/json" in content_type:
            body = json.loads(event.get("body", "{}"))
            image_data = body.get("image")
            filename = body.get("filename", "image.jpg")

            if not image_data:
                return response(400, {"error": "Campo 'image' es requerido"})
            
            file_bytes = base64.base64decode(image_data)

        # Si no es JSON, asumimos que el cuerpo es la imagen en base64 (API Gateway lo decodifica)
        else:
            body = event.get("body", "")
            is_base64 = event.get("isBase64Encoded", False)

            if is_base64:
                file_bytes = base64.b64decode(body)
            else:
                file_bytes = body.encode('utf-8') if isinstance(body, str) else body
            
            # Si no se proporciona un filename, intentamos inferirlo del Content-Type
            ext_map = {
                "image/jpeg": "jpg",
                "image/png": "png",
                "image/gif": "gif",
                "image/webp": "webp"
            }
            ext = ext_map.get(content_type.split(";")[0].strip(), "jpg")
            filename = f"image.{ext}"

        # Validar extensión y tamaño    
        extension = filename.rsplit('.', 1)[-1].lower() if "." in filename else ""
        if extension not in ALLOWED_EXTENSIONS:
            return response(400, {
                "error": f"Extensión no permitida: .{extension}",
                "allowed": list(ALLOWED_EXTENSIONS)
            })
        
        if len(file_bytes) > MAX_SIZE:
            return response(400, {
                "error": f"Archivo demasiado grande: {len(file_bytes)} bytes.",
                "max_size": MAX_SIZE,
            })
        
        # subir a s3 con un nombre único para evitar colisiones
        unique_name = f"{uuid.uuid4().hex}_{filename}"
        s3_key = f"{UPLOAD_PREFIX}{unique_name}"

        content_type_map = {
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "gif": "image/gif",
            "webp": "image/webp"
        }

        s3_client.put_object(
            Bucket=s3_BUCKET,
            Key=s3_key,
            Body=file_bytes,
            ContentType=content_type_map.get(extension, "application/octet-stream")
        )

        return response(200, {
            "message": "Archivo subido exitosamente",
            "s3_key": s3_key,
            "size": len(file_bytes),
        })
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {"error": "Error interno del servidor"})
    
def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }