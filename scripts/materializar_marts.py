"""
Script para materializar la Capa Mart (Gold) en AWS Athena.
Lee las consultas SQL documentadas en models/athena/sql/mart/,
ejecuta las sentencias CTAS en el Workgroup sirius-eda y valida los resultados.
"""

import boto3
import time
import os
import sys

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

REGION = "us-east-1"
WORKGROUP = "sirius-eda"
STAGING_DB = "sirius_staging_db"
MART_DB = "sirius_mart_db"
MART_BUCKET = "sirius-mart-603437461408"

SQL_DIR = os.path.join(os.path.dirname(__file__), "..", "models", "athena", "sql", "mart")

MARTS = [
    {
        "nombre": "mart_cuota_mercado_mensual",
        "archivo": "mart_cuota_mercado_mensual.sql",
        "descripcion": "Cuota de mercado mensual (2009-2026) entre Yellow, Green, FHV y FHVHV"
    },
    {
        "nombre": "mart_kpis_financieros",
        "archivo": "mart_kpis_financieros.sql",
        "descripcion": "KPIs financieros, tarifas promedio, propinas, recargos y pagos a conductores"
    },
    {
        "nombre": "mart_demanda_territorial",
        "archivo": "mart_demanda_territorial.sql",
        "descripcion": "Demanda territorial y corredores de movilidad entre zonas/distritos de NYC"
    },
    {
        "nombre": "mart_patrones_temporales",
        "archivo": "mart_patrones_temporales.sql",
        "descripcion": "Patrones temporales, horas pico y distribución semanal"
    }
]

def ejecutar_query_athena(athena, query_str, db_name):
    resp = athena.start_query_execution(
        QueryString=query_str,
        QueryExecutionContext={"Database": db_name},
        ResultConfiguration={"OutputLocation": f"s3://{MART_BUCKET}/result_eda/"},
        WorkGroup=WORKGROUP
    )
    qid = resp["QueryExecutionId"]
    inicio = time.time()
    
    while True:
        info = athena.get_query_execution(QueryExecutionId=qid)["QueryExecution"]
        estado = info["Status"]["State"]
        if estado in ["SUCCEEDED", "FAILED", "CANCELLED"]:
            duracion = round(time.time() - inicio, 1)
            scanned_bytes = info.get("Statistics", {}).get("DataScannedInBytes", 0)
            scanned_mb = round(scanned_bytes / (1024 * 1024), 2)
            return estado, duracion, scanned_mb, info["Status"].get("StateChangeReason", "")
        time.sleep(3)

def contar_filas_tabla(athena, db_name, tabla):
    query = f"SELECT COUNT(*) FROM {db_name}.{tabla}"
    estado, _, _, _ = ejecutar_query_athena(athena, query, db_name)
    if estado == "SUCCEEDED":
        # Obtener resultado
        resp = athena.start_query_execution(
            QueryString=query,
            QueryExecutionContext={"Database": db_name},
            ResultConfiguration={"OutputLocation": f"s3://{MART_BUCKET}/result_eda/"},
            WorkGroup=WORKGROUP
        )
        qid = resp["QueryExecutionId"]
        while True:
            st = athena.get_query_execution(QueryExecutionId=qid)["QueryExecution"]["Status"]["State"]
            if st in ["SUCCEEDED", "FAILED", "CANCELLED"]:
                break
            time.sleep(1)
        res = athena.get_query_results(QueryExecutionId=qid)
        return res["ResultSet"]["Rows"][1]["Data"][0]["VarCharValue"]
    return "N/A"

def main():
    print("=" * 75)
    print("PROYECTO SIRIUS - MATERIALIZACION DE LA CAPA GOLD (DATA MARTS)")
    print(f"   Workgroup: {WORKGROUP} | Base de Datos: {MART_DB}")
    print("=" * 75)

    athena = boto3.client("athena", region_name=REGION)
    s3 = boto3.client("s3", region_name=REGION)

    for mart in MARTS:
        nombre = mart["nombre"]
        archivo_path = os.path.join(SQL_DIR, mart["archivo"])
        
        print(f"\n[MART] Procesando: {nombre}")
        print(f"   Descripcion: {mart['descripcion']}")
        
        if not os.path.exists(archivo_path):
            print(f"   [ERROR] Archivo SQL no encontrado: {archivo_path}")
            continue

        with open(archivo_path, "r", encoding="utf-8") as f:
            query_raw = f.read()

        # Reemplazar variables de plantilla
        query = query_raw.replace("${staging_db}", STAGING_DB)
        query = query.replace("${mart_db}", MART_DB)
        query = query.replace("${mart_bucket}", MART_BUCKET)

        # Si la tabla ya existe, eliminarla previamente para recreación limpia
        print(f"   Limpiando posibles datos previos en {MART_DB}.{nombre}...")
        drop_query = f"DROP TABLE IF EXISTS {MART_DB}.{nombre}"
        ejecutar_query_athena(athena, drop_query, MART_DB)

        # Limpiar prefijo S3 correspondiente
        prefix = f"mart/{nombre}/"
        objs = s3.list_objects_v2(Bucket=MART_BUCKET, Prefix=prefix)
        if "Contents" in objs:
            delete_keys = [{"Key": obj["Key"]} for obj in objs["Contents"]]
            s3.delete_objects(Bucket=MART_BUCKET, Delete={"Objects": delete_keys})

        print(f"   Ejecutando CTAS en Athena...")
        estado, duracion, scanned_mb, razon = ejecutar_query_athena(athena, query, STAGING_DB)

        if estado == "SUCCEEDED":
            filas = contar_filas_tabla(athena, MART_DB, nombre)
            print(f"   [OK] Tiempo: {duracion}s | Datos Escaneados: {scanned_mb} MB | Filas: {filas}")
        else:
            print(f"   [ERROR] Razon: {razon}")

    print("\n" + "=" * 75)
    print("Materializacion finalizada. Tablas listas en Athena para Power BI.")
    print("=" * 75)

if __name__ == "__main__":
    main()
