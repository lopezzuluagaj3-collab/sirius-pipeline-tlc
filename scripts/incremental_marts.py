"""
Script para Carga Incremental de la Capa Gold (Data Marts) en AWS Athena.

Diferencia de Responsabilidad:
- `scripts/materializar_marts.py`: Reconstruccion total / Disaster Recovery (DROP + CTAS de 18 años).
- `scripts/incremental_marts.py`: Carga incremental periodica (INSERT INTO de periodos nuevos).

Permite agregar un nuevo anio/mes a los Data Marts escaneando unicamentes las
particiones relevantes de la capa Staging, reduciendo el costo y tiempo a segundos.
"""

import argparse
import boto3
import sys
import time

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

def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Carga incremental de nuevos datos desde Staging a la Capa Mart en Athena."
    )
    parser.add_argument(
        "--anio",
        type=str,
        required=True,
        help="Anio del periodo a incorporar (ej. 2026)"
    )
    parser.add_argument(
        "--mes",
        type=str,
        required=True,
        help="Mes del periodo a incorporar (ej. 03 o 3)"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Fuerza la insercion incluso si ya existen registros para ese periodo en el Mart."
    )
    return parser.parse_args()

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
        time.sleep(2)

def obtener_resultado_escalar(athena, query_str, db_name):
    estado, _, _, razon = ejecutar_query_athena(athena, query_str, db_name)
    if estado != "SUCCEEDED":
        return None
    resp = athena.start_query_execution(
        QueryString=query_str,
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
    return res["ResultSet"]["Rows"][1]["Data"][0].get("VarCharValue", "0")

def validar_datos_en_staging(athena, anio, mes):
    print(f"\n[1/3] Validando existencia de datos en Capa Staging para {anio}-{mes}...")
    query = f"""
    SELECT
      (SELECT COUNT(*) FROM {STAGING_DB}.taxi WHERE anio = '{anio}' AND mes = '{mes}') +
      (SELECT COUNT(*) FROM {STAGING_DB}.fhvhv WHERE anio = '{anio}' AND mes = '{mes}') +
      (SELECT COUNT(*) FROM {STAGING_DB}.fhv WHERE anio = '{anio}' AND mes = '{mes}') AS total_filas
    """
    total = obtener_resultado_escalar(athena, query, STAGING_DB)
    filas = int(total) if total else 0
    if filas == 0:
        print(f"   [AVISO] No se encontraron registros en Staging para el periodo {anio}-{mes}.")
        return False
    print(f"   [OK] {filas:,} registros encontrados en Staging listos para procesar.")
    return True

def verificar_periodo_existente_en_mart(athena, anio, mes):
    query = f"""
    SELECT COUNT(*) FROM {MART_DB}.mart_cuota_mercado_mensual
    WHERE anio = '{anio}' AND mes = '{mes}'
    """
    total = obtener_resultado_escalar(athena, query, MART_DB)
    return int(total) if total else 0

def insertar_incremental_cuota_mercado(athena, anio, mes):
    print(f"\n[2/3] Insertando incremental en mart_cuota_mercado_mensual...")
    query = f"""
    INSERT INTO {MART_DB}.mart_cuota_mercado_mensual
    WITH viajes_por_servicio AS (
      SELECT
        anio,
        mes,
        tipo_taxi AS tipo_servicio,
        COUNT(*) AS total_viajes
      FROM {STAGING_DB}.taxi
      WHERE anio = '{anio}' AND mes = '{mes}'
      GROUP BY anio, mes, tipo_taxi

      UNION ALL

      SELECT
        anio,
        mes,
        'fhvhv' AS tipo_servicio,
        COUNT(*) AS total_viajes
      FROM {STAGING_DB}.fhvhv
      WHERE anio = '{anio}' AND mes = '{mes}'
      GROUP BY anio, mes

      UNION ALL

      SELECT
        anio,
        mes,
        'fhv' AS tipo_servicio,
        COUNT(*) AS total_viajes
      FROM {STAGING_DB}.fhv
      WHERE anio = '{anio}' AND mes = '{mes}'
      GROUP BY anio, mes
    ),
    totales_mensuales AS (
      SELECT
        anio,
        mes,
        tipo_servicio,
        total_viajes,
        SUM(total_viajes) OVER (PARTITION BY anio, mes) AS total_viajes_mes
      FROM viajes_por_servicio
    )
    SELECT
      anio,
      mes,
      tipo_servicio,
      total_viajes,
      total_viajes_mes,
      ROUND(100.0 * total_viajes / NULLIF(total_viajes_mes, 0), 2) AS cuota_mercado_pct
    FROM totales_mensuales
    ORDER BY anio, mes, tipo_servicio;
    """
    estado, duracion, scanned_mb, razon = ejecutar_query_athena(athena, query, MART_DB)
    if estado == "SUCCEEDED":
        print(f"   [OK] Completado en {duracion}s | Escaneado: {scanned_mb} MB")
    else:
        print(f"   [ERROR] Fallo al insertar: {razon}")
    return estado == "SUCCEEDED"

def insertar_incremental_kpis_financieros(athena, anio, mes):
    print(f"\n[3/3] Insertando incremental en mart_kpis_financieros...")
    query = f"""
    INSERT INTO {MART_DB}.mart_kpis_financieros
    WITH kpis_taxi AS (
      SELECT
        anio,
        mes,
        tipo_taxi AS tipo_servicio,
        COUNT(*) AS total_viajes,
        ROUND(SUM(total_amount), 2) AS ingreso_bruto_total,
        ROUND(AVG(fare_amount), 2) AS tarifa_base_promedio,
        ROUND(SUM(tip_amount), 2) AS propina_total,
        ROUND(AVG(tip_amount), 2) AS propina_promedio,
        ROUND(100.0 * SUM(tip_amount) / NULLIF(SUM(fare_amount), 0), 2) AS porcentaje_propina,
        ROUND(SUM(tolls_amount), 2) AS peajes_total,
        ROUND(SUM(congestion_surcharge), 2) AS recargo_congestion_total,
        ROUND(AVG(trip_distance), 2) AS distancia_promedio_millas,
        ROUND(AVG(date_diff('second', pickup_datetime, dropoff_datetime) / 60.0), 2) AS duracion_promedio_min,
        ROUND(SUM(fare_amount) / NULLIF(SUM(trip_distance), 0), 2) AS tarifa_promedio_por_milla,
        CAST(NULL AS DOUBLE) AS pago_conductor_total,
        CAST(NULL AS DOUBLE) AS pago_conductor_promedio_viaje
      FROM {STAGING_DB}.taxi
      WHERE anio = '{anio}' AND mes = '{mes}'
        AND trip_distance > 0
        AND fare_amount > 0
        AND total_amount > 0
        AND dropoff_datetime >= pickup_datetime
      GROUP BY anio, mes, tipo_taxi
    ),
    kpis_fhvhv AS (
      SELECT
        anio,
        mes,
        'fhvhv' AS tipo_servicio,
        COUNT(*) AS total_viajes,
        ROUND(SUM(base_passenger_fare + tolls + bcf + sales_tax + congestion_surcharge + airport_fee + tips), 2) AS ingreso_bruto_total,
        ROUND(AVG(base_passenger_fare), 2) AS tarifa_base_promedio,
        ROUND(SUM(tips), 2) AS propina_total,
        ROUND(AVG(tips), 2) AS propina_promedio,
        ROUND(100.0 * SUM(tips) / NULLIF(SUM(base_passenger_fare), 0), 2) AS porcentaje_propina,
        ROUND(SUM(tolls), 2) AS peajes_total,
        ROUND(SUM(congestion_surcharge), 2) AS recargo_congestion_total,
        ROUND(AVG(trip_miles), 2) AS distancia_promedio_millas,
        ROUND(AVG(trip_time / 60.0), 2) AS duracion_promedio_min,
        ROUND(SUM(base_passenger_fare) / NULLIF(SUM(trip_miles), 0), 2) AS tarifa_promedio_por_milla,
        ROUND(SUM(driver_pay), 2) AS pago_conductor_total,
        ROUND(AVG(driver_pay), 2) AS pago_conductor_promedio_viaje
      FROM {STAGING_DB}.fhvhv
      WHERE anio = '{anio}' AND mes = '{mes}'
        AND trip_miles > 0
        AND base_passenger_fare > 0
        AND trip_time > 0
      GROUP BY anio, mes
    )
    SELECT * FROM kpis_taxi
    UNION ALL
    SELECT * FROM kpis_fhvhv;
    """
    estado, duracion, scanned_mb, razon = ejecutar_query_athena(athena, query, MART_DB)
    if estado == "SUCCEEDED":
        print(f"   [OK] Completado en {duracion}s | Escaneado: {scanned_mb} MB")
    else:
        print(f"   [ERROR] Fallo al insertar: {razon}")
    return estado == "SUCCEEDED"

def main():
    args = parse_arguments()
    anio = str(args.anio).strip()
    mes = str(args.mes).strip().zfill(2)

    print("=" * 75)
    print("PROYECTO SIRIUS - CARGA INCREMENTAL A CAPA GOLD (DATA MARTS)")
    print(f"   Periodo objetivo: Anio={anio}, Mes={mes}")
    print(f"   Workgroup: {WORKGROUP} | Base de datos: {MART_DB}")
    print("=" * 75)

    athena = boto3.client("athena", region_name=REGION)

    # 1. Validar si los datos existen en Staging
    hay_datos = validar_datos_en_staging(athena, anio, mes)
    if not hay_datos:
        sys.exit(1)

    # 2. Guardia de Idempotencia: Verificar si ya existe en Mart
    existentes = verificar_periodo_existente_en_mart(athena, anio, mes)
    if existentes > 0 and not args.force:
        print(f"\n[ALERTA DE IDEMPOTENCIA]")
        print(f"   El periodo {anio}-{mes} ya cuenta con {existentes} registros en mart_cuota_mercado_mensual.")
        print(f"   Para evitar duplicar registros en el Data Mart, la operacion se cancelo.")
        print(f"   Si deseas forzar la insercion, ejecuta con la bandera --force.")
        sys.exit(0)

    # 3. Insercion incremental
    ok_cuota = insertar_incremental_cuota_mercado(athena, anio, mes)
    ok_kpis = insertar_incremental_kpis_financieros(athena, anio, mes)

    print("\n" + "=" * 75)
    if ok_cuota and ok_kpis:
        print(f"Carga incremental para {anio}-{mes} exitosa.")
        print(f"Las tablas Mart estan actualizadas. Power BI puede reimportar los datos.")
    else:
        print("La carga incremental presento errores en una o mas tablas.")
    print("=" * 75)

if __name__ == "__main__":
    main()
