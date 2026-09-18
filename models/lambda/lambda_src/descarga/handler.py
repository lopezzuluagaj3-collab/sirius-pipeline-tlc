"""
Lambda de descarga - Proyecto Sirius

Se dispara por cada mensaje de la cola SQS de periodos faltantes.
Descarga el Parquet correspondiente desde la fuente oficial de NYC TLC
y lo sube a la zona raw de S3, respetando particionamiento estilo Hive
(anio=/mes=) para que Glue y Athena lo detecten sin trabajo adicional.

No transforma nada: ese trabajo le corresponde al Glue Job de staging.
"""

import json
import os
import shutil
import tempfile
import urllib.request

import boto3

s3 = boto3.client("s3")
sts = boto3.client("sts")

ROW_BUCKET = os.environ.get("ROW_BUCKET", os.environ.get("RAW_BUCKET", ""))
ACCOUNT_ID = sts.get_caller_identity()["Account"]


def descargar_archivo(url: str) -> tuple[int, str]:
    fd, tmp_path = tempfile.mkstemp()
    os.close(fd)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "sirius-tlc-ingesta/1.0"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            if resp.status != 200:
                raise RuntimeError(f"Descarga fallida desde {url}: HTTP {resp.status}")
            with open(tmp_path, "wb") as archivo:
                shutil.copyfileobj(resp, archivo)

        size = os.path.getsize(tmp_path)
        if size <= 0:
            raise RuntimeError(f"Descarga vacia desde {url}")
        return size, tmp_path
    except Exception:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        raise


def handler(event, context):
    resultados = []

    for record in event["Records"]:
        body = json.loads(record["body"])
        formato = body["formato"]
        anio = body["anio"]
        mes = body["mes"]
        url = body["url"]

        nombre_archivo = f"{formato}_tripdata_{anio:04d}-{mes:02d}.parquet"
        key = f"row/{formato}/anio={anio:04d}/mes={mes:02d}/{nombre_archivo}"

        size, tmp_path = descargar_archivo(url)
        try:
            s3.upload_file(
                tmp_path,
                ROW_BUCKET,
                key,
                ExtraArgs={"ExpectedBucketOwner": ACCOUNT_ID},
            )
        finally:
            os.remove(tmp_path)

        resultados.append({"formato": formato, "anio": anio, "mes": mes, "key": key, "bytes": size})

    return {"cargados": resultados}
