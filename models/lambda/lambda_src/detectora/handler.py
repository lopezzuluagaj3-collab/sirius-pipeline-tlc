"""
Lambda detectora - Proyecto Sirius

Compara los periodos (anio, mes) ya presentes en la zona raw de S3 contra
los periodos publicados en la fuente oficial de NYC TLC, y encola en SQS
un mensaje por cada periodo faltante para que la Lambda de descarga lo
procese.

No descarga ni transforma nada: solo decide QUE falta.
"""

import json
import os
import urllib.request
from datetime import date

import boto3

s3 = boto3.client("s3")
sqs = boto3.client("sqs")

ROW_BUCKET = os.environ.get("ROW_BUCKET", os.environ.get("RAW_BUCKET", ""))
QUEUE_URL = os.environ["QUEUE_URL"]
TLC_BASE_URL = os.environ["TLC_BASE_URL"]
FORMATOS = os.environ.get("FORMATOS", "yellow,green,fhv,fhvhv").split(",")
FECHA_INICIO = os.environ.get("FECHA_INICIO", "2015-01")  # YYYY-MM
FECHA_INICIO_POR_FORMATO = json.loads(os.environ.get("FECHA_INICIO_POR_FORMATO", "{}"))


def periodos_esperados(fecha_inicio: str) -> list[tuple[int, int]]:
    """Genera (anio, mes) desde fecha_inicio hasta el mes anterior al actual,
    que es el ultimo periodo que TLC suele tener publicado."""
    anio_ini, mes_ini = (int(p) for p in fecha_inicio.split("-"))
    hoy = date.today()
    anio_fin, mes_fin = hoy.year, hoy.month - 1
    if mes_fin == 0:
        anio_fin -= 1
        mes_fin = 12

    periodos = []
    anio, mes = anio_ini, mes_ini
    while (anio, mes) <= (anio_fin, mes_fin):
        periodos.append((anio, mes))
        mes += 1
        if mes > 12:
            mes = 1
            anio += 1
    return periodos


def periodos_en_s3(formato: str) -> set[tuple[int, int]]:
    """Lista los periodos ya presentes en S3 para un formato.

    Solo cuenta objetos con bytes reales. Un objeto de 0 bytes se trata como
    faltante para que pueda reprocesarse.
    """
    existentes = set()
    prefix = f"row/{formato}/"
    paginator = s3.get_paginator("list_objects_v2")

    for pagina in paginator.paginate(Bucket=ROW_BUCKET, Prefix=prefix):
        for obj in pagina.get("Contents", []):
            if obj.get("Size", 0) <= 0:
                continue

            key = obj["Key"]
            try:
                anio = int(key.split("/anio=")[1].split("/")[0])
                mes = int(key.split("/mes=")[1].split("/")[0])
            except (IndexError, ValueError):
                continue

            existentes.add((anio, mes))

    return existentes


DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)


def existe_en_tlc(formato: str, anio: int, mes: int) -> bool:
    """Confirma con un HEAD request que el archivo ya fue publicado por TLC,
    en vez de parsear el HTML de la pagina (mas fragil ante cambios)."""
    url = f"{TLC_BASE_URL}/{formato}_tripdata_{anio:04d}-{mes:02d}.parquet"
    req = urllib.request.Request(
        url,
        method="HEAD",
        headers={"User-Agent": DEFAULT_USER_AGENT, "Accept": "*/*"},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status in (200, 202)
    except Exception:
        return False


def handler(event, context):
    total_encolados = 0
    detalle = {}

    for formato in FORMATOS:
        fecha_inicio = FECHA_INICIO_POR_FORMATO.get(formato, FECHA_INICIO)
        esperados = set(periodos_esperados(fecha_inicio))
        existentes = periodos_en_s3(formato)
        candidatos = sorted(esperados - existentes)

        faltantes = []
        for anio, mes in candidatos:
            if existe_en_tlc(formato, anio, mes):
                faltantes.append((anio, mes))

        for anio, mes in faltantes:
            mensaje = {
                "formato": formato,
                "anio": anio,
                "mes": mes,
                "url": f"{TLC_BASE_URL}/{formato}_tripdata_{anio:04d}-{mes:02d}.parquet",
            }
            sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(mensaje))
            total_encolados += 1

        detalle[formato] = [f"{a:04d}-{m:02d}" for a, m in faltantes]

    return {
        "total_encolados": total_encolados,
        "detalle": detalle,
    }
