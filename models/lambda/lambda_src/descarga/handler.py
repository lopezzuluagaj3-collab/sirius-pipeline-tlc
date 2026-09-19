"""
Lambda de descarga - Proyecto Sirius

Se dispara por cada mensaje de la cola SQS de periodos faltantes.
Descarga el Parquet correspondiente desde la fuente oficial de NYC TLC
en streaming (chunks de 64 KB para no saturar la memoria RAM) y lo sube a la
zona row de S3 con particionamiento Hive (anio=/mes=).

Incluye limpieza inmediata de disco (/tmp) y recolección forzada de memoria (gc.collect())
para evitar cuellos de botella y memory leaks en ejecuciones consecutivas del contenedor.
"""

import gc
import json
import os
import shutil
import tempfile
import time
import urllib.error
import urllib.request

import boto3

s3 = boto3.client("s3")
sts = boto3.client("sts")
glue = boto3.client("glue")

ROW_BUCKET = os.environ.get("ROW_BUCKET", os.environ.get("RAW_BUCKET", ""))
GLUE_JOB_NAME = os.environ.get("GLUE_JOB_NAME", "")
ACCOUNT_ID = sts.get_caller_identity()["Account"]


DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)


def descargar_archivo(url: str, max_retries: int = 5, base_delay: float = 3.0) -> tuple[int, str]:
    headers = {
        "User-Agent": DEFAULT_USER_AGENT,
        "Accept": "*/*",
    }
    delay = base_delay

    for intento in range(1, max_retries + 1):
        fd, tmp_path = tempfile.mkstemp(prefix="sirius_descarga_", suffix=".parquet")
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=120) as resp:
                if resp.status == 200:
                    with os.fdopen(fd, "wb") as archivo:
                        shutil.copyfileobj(resp, archivo, length=64 * 1024)

                    size = os.path.getsize(tmp_path)
                    if size <= 0:
                        raise RuntimeError(f"Descarga vacia desde {url}")
                    return size, tmp_path

                if resp.status == 202:
                    os.close(fd)
                    if os.path.exists(tmp_path):
                        os.remove(tmp_path)
                    if intento < max_retries:
                        print(f"Intento {intento}/{max_retries}: HTTP 202 (Accepted) en {url}. Esperando {delay:.1f}s...")
                        time.sleep(delay)
                        delay *= 1.5
                        continue
                    raise RuntimeError(f"Descarga fallida desde {url}: HTTP 202 tras {max_retries} intentos")

                raise RuntimeError(f"Descarga fallida desde {url}: HTTP {resp.status}")

        except urllib.error.HTTPError as e:
            try:
                os.close(fd)
            except OSError:
                pass
            if os.path.exists(tmp_path):
                try:
                    os.remove(tmp_path)
                except OSError:
                    pass

            if e.code == 202 and intento < max_retries:
                print(f"Intento {intento}/{max_retries}: HTTPError 202 en {url}. Esperando {delay:.1f}s...")
                time.sleep(delay)
                delay *= 1.5
                continue
            raise

        except Exception:
            try:
                os.close(fd)
            except OSError:
                pass
            if os.path.exists(tmp_path):
                try:
                    os.remove(tmp_path)
                except OSError:
                    pass
            raise

    raise RuntimeError(f"Descarga no completada desde {url}")


def limpiar_residuos_temporales():
    """Elimina residuos en /tmp y fuerza recolección de basura de Python."""
    tmp_dir = tempfile.gettempdir()
    for f in os.listdir(tmp_dir):
        if f.startswith("sirius_descarga_"):
            try:
                os.remove(os.path.join(tmp_dir, f))
            except OSError:
                pass
    gc.collect()


def handler(event, context):
    resultados = []

    try:
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
                if os.path.exists(tmp_path):
                    try:
                        os.remove(tmp_path)
                    except OSError:
                        pass
                del tmp_path
                gc.collect()

            job_run_id = None
            if GLUE_JOB_NAME:
                try:
                    glue_resp = glue.start_job_run(
                        JobName=GLUE_JOB_NAME,
                        Arguments={
                            "--formato": str(formato),
                            "--anio": f"{int(anio):04d}",
                            "--mes": f"{int(mes):02d}",
                        },
                    )
                    job_run_id = glue_resp.get("JobRunId")
                    print(f"Glue Job '{GLUE_JOB_NAME}' disparado para {formato} {anio:04d}-{mes:02d}. RunId: {job_run_id}")
                except Exception as e:
                    print(f"Error disparando Glue Job para {formato} {anio:04d}-{mes:02d}: {e}")

            resultados.append({
                "formato": formato,
                "anio": anio,
                "mes": mes,
                "key": key,
                "bytes": size,
                "glue_run_id": job_run_id,
            })

        return {"cargados": resultados}
    finally:
        limpiar_residuos_temporales()

