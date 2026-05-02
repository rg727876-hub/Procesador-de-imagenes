"""
Crop Lambda — Recibe eventos de SQS, descarga imagen de S3,
la recorta en círculo de 40x40 px y la sube a processed/.
Responsabilidad única: solo procesar la imagen.
"""

import json
import os
import io
import boto3
from PIL import Image, ImageDraw

s3_client = boto3.client("s3")

S3_BUCKET = os.environ["S3_BUCKET"]
PROCESSED_PREFIX = os.environ.get("PROCESSED_PREFIX", "processed/")

OUTPUT_SIZE = 40  # 40x40 px

def handler(event, context):
    """
    Procesa mensajes de SQS (batch).
    Usa ReportBatchItemFailures para reportar items individuales fallidos.
    """
    batch_item_failures = []

    for record in event.get("Records", []):
        message_id = record["messageId"]
        try:
            # El body del SQS contiene la notificación de S3
            s3_event = json.loads(record["body"])

            for s3_record in s3_event.get("Records", []):
                source_key = s3_record["s3"]["object"]["key"]
                bucket = s3_record["s3"]["bucket"]["name"]

                print(f"Procesando: s3://{bucket}/{source_key}")

                # Descargar imagen original
                response = s3_client.get_object(Bucket=bucket, Key=source_key)
                image_bytes = response["Body"].read()

                # Procesar: recortar en círculo 40x40
                processed_bytes = crop_circle(image_bytes)

                # Nombre de salida: nombre_circular.png
                original_name = source_key.split("/")[-1]
                base_name = original_name.rsplit(".", 1)[0]
                output_key = f"{PROCESSED_PREFIX}{base_name}_circular.png"

                # Subir imagen procesada
                s3_client.put_object(
                    Bucket=bucket,
                    Key=output_key,
                    Body=processed_bytes,
                    ContentType="image/png",
                )

                print(f"Guardado: s3://{bucket}/{output_key}")

        except Exception as e:
            print(f"Error procesando mensaje {message_id}: {str(e)}")
            batch_item_failures.append({"itemIdentifier": message_id})

    return {"batchItemFailures": batch_item_failures}

def crop_circle(image_bytes):
    """
    Toma bytes de una imagen, la redimensiona a 40x40 (cover/crop)
    y aplica una máscara circular con fondo transparente.
    """
    # Abrir imagen y convertir a RGBA
    img = Image.open(io.BytesIO(image_bytes)).convert("RGBA")

    # Resize tipo "cover": recortar al centro manteniendo aspecto
    width, height = img.size
    min_dim = min(width, height)

    # Recortar cuadrado del centro
    left = (width - min_dim) // 2
    top = (height - min_dim) // 2
    right = left + min_dim
    bottom = top + min_dim
    img = img.crop((left, top, right, bottom))

    # Redimensionar a 40x40
    img = img.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.LANCZOS)

    # Crear máscara circular
    mask = Image.new("L", (OUTPUT_SIZE, OUTPUT_SIZE), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, OUTPUT_SIZE - 1, OUTPUT_SIZE - 1), fill=255)

    # Aplicar máscara: fondo transparente fuera del círculo
    output = Image.new("RGBA", (OUTPUT_SIZE, OUTPUT_SIZE), (0, 0, 0, 0))
    output.paste(img, mask=mask)

    # Exportar como PNG
    buffer = io.BytesIO()
    output.save(buffer, format="PNG")
    buffer.seek(0)

    return buffer.read()