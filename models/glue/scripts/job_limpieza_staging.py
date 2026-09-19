import re
import sys
import boto3
from concurrent.futures import ThreadPoolExecutor, as_completed
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F
from pyspark.sql.types import (
    LongType,
    IntegerType,
    DoubleType,
    StringType,
    TimestampType,
)

# -------------------------------------------------------------------------
# 1. Inicialización y Captura de Argumentos
# -------------------------------------------------------------------------

args = getResolvedOptions(
    sys.argv,
    [
        "JOB_NAME",
        "ROW_BUCKET",
        "STAGING_BUCKET",
    ]
)

optional_params = ["formato", "anio", "mes"]
cli_args = {}
for param in optional_params:
    if f"--{param}" in sys.argv:
        opt = getResolvedOptions(sys.argv, [param])
        cli_args[param] = opt[param]

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# Configuraciones de robustez en Spark
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
spark.conf.set("spark.sql.parquet.mergeSchema", "false")
spark.conf.set("spark.sql.parquet.enableVectorizedReader", "false")
spark.conf.set("spark.sql.shuffle.partitions", "64")

row_bucket = args["ROW_BUCKET"]
staging_bucket = args["STAGING_BUCKET"]
filtro_formato = cli_args.get("formato")
filtro_anio = cli_args.get("anio")
filtro_mes = cli_args.get("mes")

s3_client = boto3.client("s3")

print("==========================================================")
print(f"Iniciando Glue Job: {args['JOB_NAME']}")
print(f"Bucket Origen (Raw): s3://{row_bucket}/row/")
print(f"Bucket Destino (Staging): s3://{staging_bucket}/staging/")
print(f"Filtros CLI: formato={filtro_formato}, anio={filtro_anio}, mes={filtro_mes}")
print("==========================================================")


# -------------------------------------------------------------------------
# 2. Funciones de Transformación y Limpieza por Formato
# -------------------------------------------------------------------------

def safe_cast(df, col_name, target_type):
    """Castea de forma ultra-robusta convirtiendo primero a String para desacoplar discrepancias de esquemas y tipos binarios."""
    if col_name in df.columns:
        # Convertir primero a String como capa de aislamiento universal
        col_str = F.col(col_name).cast(StringType())
        # Si el tipo destino es entero/long, pasar por Double primero por si viene con formato '1.0'
        if isinstance(target_type, (LongType, IntegerType)):
            return df.withColumn(col_name, col_str.cast(DoubleType()).cast(target_type))
        else:
            return df.withColumn(col_name, col_str.cast(target_type))
    return df


def limpiar_yellow(df):
    """Aplica las reglas del EDA para Yellow Taxi y unifica esquema a 'taxi'."""
    # 1. Normalizar todos los nombres de columnas a minúsculas
    for c in df.columns:
        df = df.withColumnRenamed(c, c.lower())

    # 2. Mapear alias y nombres antiguos (2009-2014)
    alias_map = {
        "fare_amt": "fare_amount",
        "total_amt": "total_amount",
        "tip_amt": "tip_amount",
        "tolls_amt": "tolls_amount",
        "surcharge": "extra",
        "rate_code": "ratecodeid",
        "trip_pickup_datetime": "pickup_datetime",
        "tpep_pickup_datetime": "pickup_datetime",
        "trip_dropoff_datetime": "dropoff_datetime",
        "tpep_dropoff_datetime": "dropoff_datetime",
        "store_and_forward": "store_and_fwd_flag",
    }
    for old_c, new_c in alias_map.items():
        if old_c in df.columns and new_c not in df.columns:
            df = df.withColumnRenamed(old_c, new_c)

    # 3. Estandarizar vendor_name ('CMT'/'VTS') a vendorid
    if "vendor_name" in df.columns and "vendorid" not in df.columns:
        df = df.withColumn("vendorid", F.when(F.upper(F.col("vendor_name").cast(StringType())) == "CMT", F.lit(1).cast(LongType()))
                                        .when(F.upper(F.col("vendor_name").cast(StringType())) == "VTS", F.lit(2).cast(LongType()))
                                        .otherwise(F.lit(None).cast(LongType())))
    elif "vendor_id" in df.columns and "vendorid" not in df.columns:
        df = safe_cast(df, "vendor_id", LongType()).withColumnRenamed("vendor_id", "vendorid")

    # 4. Asegurar existencia y tipo de todas las columnas enteras canónicas (pasando por String)
    cols_int = ["vendorid", "passenger_count", "ratecodeid", "pulocationid", "dolocationid", "trip_type"]
    for c in cols_int:
        if c not in df.columns:
            df = df.withColumn(c, F.lit(None).cast(LongType()))
        else:
            df = safe_cast(df, c, LongType())

    # 5. Asegurar existencia y tipo de todas las columnas flotantes canónicas (pasando por String)
    cols_double = [
        "trip_distance", "fare_amount", "extra", "mta_tax", "tip_amount",
        "tolls_amount", "improvement_surcharge", "total_amount",
        "congestion_surcharge", "airport_fee", "ehail_fee"
    ]
    for c in cols_double:
        if c not in df.columns:
            df = df.withColumn(c, F.lit(None).cast(DoubleType()))
        else:
            df = safe_cast(df, c, DoubleType())

    # 6. Normalizar payment_type (en 2009 viene 'CAS', 'CRD' etc.)
    if "payment_type" in df.columns:
        df = df.withColumn(
            "payment_type",
            F.when(F.upper(F.col("payment_type").cast(StringType())).isin(["CAS", "CASH"]), F.lit(2).cast(LongType()))
             .when(F.upper(F.col("payment_type").cast(StringType())).isin(["CRD", "CREDIT"]), F.lit(1).cast(LongType()))
             .when(F.upper(F.col("payment_type").cast(StringType())).isin(["NOC", "NO CHARGE"]), F.lit(3).cast(LongType()))
             .when(F.upper(F.col("payment_type").cast(StringType())).isin(["DIS", "DISPUTE"]), F.lit(4).cast(LongType()))
             .otherwise(F.col("payment_type").cast(LongType()))
        )
    else:
        df = df.withColumn("payment_type", F.lit(None).cast(LongType()))

    if "store_and_fwd_flag" not in df.columns:
        df = df.withColumn("store_and_fwd_flag", F.lit(None).cast(StringType()))
    else:
        df = df.withColumn("store_and_fwd_flag", F.col("store_and_fwd_flag").cast(StringType()))

    # 7. Convertir timestamps
    df = df.withColumn("pickup_datetime", F.to_timestamp(F.col("pickup_datetime"))) \
           .withColumn("dropoff_datetime", F.to_timestamp(F.col("dropoff_datetime")))

    # 8. Reglas de Calidad EDA
    df = df.filter(F.col("dropoff_datetime") >= F.col("pickup_datetime"))
    df = df.filter(F.year(F.col("pickup_datetime")).between(2009, 2026))
    df = df.filter(
        (F.col("fare_amount").isNull() | (F.col("fare_amount") >= 0)) &
        (F.col("trip_distance").isNull() | (F.col("trip_distance") >= 0))
    )

    dedup_cols = [c for c in ["vendorid", "pickup_datetime", "dropoff_datetime", "fare_amount"] if c in df.columns]
    if len(dedup_cols) >= 3:
        df = df.dropDuplicates(subset=dedup_cols)

    df = df.withColumn("tipo_taxi", F.lit("yellow")) \
           .withColumn("anio", F.year(F.col("pickup_datetime")).cast(StringType())) \
           .withColumn("mes", F.lpad(F.month(F.col("pickup_datetime")).cast(StringType()), 2, "0"))

    return df



def limpiar_green(df):
    """Aplica las reglas del EDA para Green Taxi y unifica esquema a 'taxi'."""
    if "lpep_pickup_datetime" in df.columns:
        df = df.withColumnRenamed("lpep_pickup_datetime", "pickup_datetime")
    if "lpep_dropoff_datetime" in df.columns:
        df = df.withColumnRenamed("lpep_dropoff_datetime", "dropoff_datetime")

    cols_int = ["vendorid", "passenger_count", "ratecodeid", "pulocationid", "dolocationid", "trip_type"]
    for c in cols_int:
        df = safe_cast(df, c, LongType())

    cols_double = [
        "trip_distance", "fare_amount", "extra", "mta_tax", "tip_amount",
        "tolls_amount", "ehail_fee", "improvement_surcharge", "total_amount",
        "congestion_surcharge"
    ]
    for c in cols_double:
        df = safe_cast(df, c, DoubleType())

    if "payment_type" in df.columns:
        df = df.withColumn("payment_type", F.col("payment_type").cast(LongType()))

    df = df.withColumn("pickup_datetime", F.to_timestamp(F.col("pickup_datetime"))) \
           .withColumn("dropoff_datetime", F.to_timestamp(F.col("dropoff_datetime")))

    df = df.filter(F.col("dropoff_datetime") >= F.col("pickup_datetime"))
    df = df.filter(F.year(F.col("pickup_datetime")).between(2014, 2026))
    df = df.filter(
        (F.col("fare_amount").isNull() | (F.col("fare_amount") >= 0)) &
        (F.col("trip_distance").isNull() | (F.col("trip_distance") >= 0))
    )

    if "pulocationid" in df.columns:
        df = df.filter(~((F.col("trip_distance") == 0) & (F.col("pulocationid").isin(264, 265))))

    dedup_cols = [c for c in ["vendorid", "pickup_datetime", "dropoff_datetime",
                             "pulocationid", "dolocationid", "fare_amount"] if c in df.columns]
    if len(dedup_cols) >= 4:
        df = df.dropDuplicates(subset=dedup_cols)

    df = df.withColumn("tipo_taxi", F.lit("green")) \
           .withColumn("anio", F.year(F.col("pickup_datetime")).cast(StringType())) \
           .withColumn("mes", F.lpad(F.month(F.col("pickup_datetime")).cast(StringType()), 2, "0"))

    if "airport_fee" not in df.columns:
        df = df.withColumn("airport_fee", F.lit(None).cast(DoubleType()))

    return df


def limpiar_fhv(df):
    """Aplica las reglas del EDA para FHV (Bases tradicionales / Livery)."""
    for c in df.columns:
        df = df.withColumnRenamed(c, c.lower())

    cols_int = ["pulocationid", "dolocationid", "sr_flag"]
    for c in cols_int:
        df = safe_cast(df, c, LongType())

    df = df.withColumn("pickup_datetime", F.to_timestamp(F.col("pickup_datetime"))) \
           .withColumn("dropoff_datetime", F.to_timestamp(F.col("dropoff_datetime")))

    df = df.withColumn(
        "dropoff_datetime",
        F.when(F.col("dropoff_datetime") == F.to_timestamp(F.lit("1989-01-01 00:00:00")), F.lit(None).cast(TimestampType()))
         .otherwise(F.col("dropoff_datetime"))
    )

    df = df.filter(F.col("dropoff_datetime").isNull() | (F.col("dropoff_datetime") >= F.col("pickup_datetime")))
    df = df.filter(F.year(F.col("pickup_datetime")).between(2015, 2026))

    dedup_cols = [c for c in ["dispatching_base_num", "pickup_datetime", "dropoff_datetime", "pulocationid", "dolocationid"] if c in df.columns]
    if len(dedup_cols) >= 3:
        df = df.dropDuplicates(subset=dedup_cols)

    df = df.withColumn("anio", F.year(F.col("pickup_datetime")).cast(StringType())) \
           .withColumn("mes", F.lpad(F.month(F.col("pickup_datetime")).cast(StringType()), 2, "0"))

    return df


def limpiar_fhvhv(df):
    """Aplica las reglas del EDA para FHVHV (Uber, Lyft, Via, Juno)."""
    for c in df.columns:
        df = df.withColumnRenamed(c, c.lower())

    cols_int = ["pulocationid", "dolocationid", "trip_time"]
    for c in cols_int:
        df = safe_cast(df, c, LongType())

    cols_double = [
        "trip_miles", "base_passenger_fare", "tolls", "bcf", "sales_tax",
        "congestion_surcharge", "airport_fee", "tips", "driver_pay"
    ]
    for c in cols_double:
        df = safe_cast(df, c, DoubleType())

    df = df.withColumn("pickup_datetime", F.to_timestamp(F.col("pickup_datetime"))) \
           .withColumn("dropoff_datetime", F.to_timestamp(F.col("dropoff_datetime")))

    df = df.filter(F.col("dropoff_datetime") >= F.col("pickup_datetime"))
    df = df.filter(F.year(F.col("pickup_datetime")).between(2019, 2026))
    df = df.filter(
        (F.col("trip_miles").isNull() | (F.col("trip_miles") >= 0)) &
        (F.col("trip_time").isNull() | (F.col("trip_time") >= 0)) &
        (F.col("base_passenger_fare").isNull() | (F.col("base_passenger_fare") >= 0))
    )

    dedup_cols = [c for c in ["hvfhs_license_num", "dispatching_base_num", "pickup_datetime",
                             "dropoff_datetime", "pulocationid", "dolocationid"] if c in df.columns]
    if len(dedup_cols) >= 4:
        df = df.dropDuplicates(subset=dedup_cols)

    df = df.withColumn("anio", F.year(F.col("pickup_datetime")).cast(StringType())) \
           .withColumn("mes", F.lpad(F.month(F.col("pickup_datetime")).cast(StringType()), 2, "0"))

    return df


# -------------------------------------------------------------------------
# 3. Descubrimiento de Particiones y Procesamiento Robusto
# -------------------------------------------------------------------------

def listar_periodos_en_s3(bucket, formato):
    """Descubre dinámicamente las particiones mensuales en S3 para el formato dado."""
    paginator = s3_client.get_paginator("list_objects_v2")
    prefix = f"row/{formato}/"
    patron = re.compile(rf"row/{formato}/anio=(\d{{4}})/mes=(\d{{2}})/")
    periodos = set()

    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for item in page.get("Contents", []):
            match = patron.search(item["Key"])
            if match:
                periodos.add((match.group(1), match.group(2)))

    return sorted(list(periodos))


def listar_periodos_existentes(bucket, formato):
    """Detecta qué particiones ya están completamente escritas en staging para resumir sin duplicar."""
    paginator = s3_client.get_paginator("list_objects_v2")
    prefix = f"staging/taxi/tipo_taxi={formato}/" if formato in ["yellow", "green"] else f"staging/{formato}/"
    patron = re.compile(rf"anio=(\d{{4}})/mes=(\d{{2}})/")
    existentes = set()

    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for item in page.get("Contents", []):
            match = patron.search(item["Key"])
            if match:
                existentes.add((match.group(1), match.group(2)))

    return existentes


formatos_a_procesar = ["yellow", "green"] if filtro_formato == "taxi" else ([filtro_formato] if filtro_formato else ["yellow", "green", "fhv", "fhvhv"])

for fmt in formatos_a_procesar:
    print(f"\n==========================================================")
    print(f"Iniciando Formato: {fmt}")
    print(f"==========================================================")

    if fmt in ["yellow", "green"]:
        target_path = f"s3://{staging_bucket}/staging/taxi/"
        partition_cols = ["tipo_taxi", "anio", "mes"]
    else:
        target_path = f"s3://{staging_bucket}/staging/{fmt}/"
        partition_cols = ["anio", "mes"]

    # Descubrir periodos totales
    if filtro_anio and filtro_mes:
        todos_los_periodos = [(filtro_anio, filtro_mes)]
    elif filtro_anio:
        todos_los_periodos = [(a, m) for a, m in listar_periodos_en_s3(row_bucket, fmt) if a == filtro_anio]
    else:
        todos_los_periodos = listar_periodos_en_s3(row_bucket, fmt)

    # Detectar períodos ya procesados en staging para no repetir trabajo
    ya_guardados = listar_periodos_existentes(staging_bucket, fmt)
    periodos = [p for p in todos_los_periodos if p not in ya_guardados]

    print(f"Total períodos en Raw: {len(todos_los_periodos)}")
    print(f"Períodos ya procesados en Staging: {len(ya_guardados)} (se omitirán)")
    print(f"Períodos pendientes a procesar: {len(periodos)}")

    MAX_WORKERS_HILOS = 4

    def procesar_un_mes(periodo):
        anio_p, mes_p = periodo
        source_path = f"s3://{row_bucket}/row/{fmt}/anio={anio_p}/mes={mes_p}/*.parquet"
        if fmt in ["yellow", "green"]:
            dest_path = f"s3://{staging_bucket}/staging/taxi/tipo_taxi={fmt}/anio={anio_p}/mes={mes_p}/"
        else:
            dest_path = f"s3://{staging_bucket}/staging/{fmt}/anio={anio_p}/mes={mes_p}/"

        print(f"Iniciando concurrente: {fmt} {anio_p}-{mes_p}...")
        try:
            df_raw = spark.read.parquet(source_path)

            if fmt == "yellow":
                df_clean = limpiar_yellow(df_raw)
            elif fmt == "green":
                df_clean = limpiar_green(df_raw)
            elif fmt == "fhv":
                df_clean = limpiar_fhv(df_raw)
            elif fmt == "fhvhv":
                df_clean = limpiar_fhvhv(df_raw)
            else:
                return (anio_p, mes_p, "OMITIDO")

            cols_drop = [c for c in ["tipo_taxi", "anio", "mes"] if c in df_clean.columns]
            df_write = df_clean.drop(*cols_drop)

            df_write.write \
                .mode("append") \
                .parquet(dest_path, compression="snappy")

            print(f"  -> OK: {fmt} {anio_p}-{mes_p} completado y guardado en staging.")
            return (anio_p, mes_p, "OK")

        except Exception as e:
            print(f"ERROR procesando periodo {fmt} {anio_p}-{mes_p}: {str(e)}")
            raise e

    if len(periodos) > 0:
        print(f"Lanzando procesamiento concurrente de {len(periodos)} períodos con {MAX_WORKERS_HILOS} hilos simultáneos...")
        with ThreadPoolExecutor(max_workers=MAX_WORKERS_HILOS) as executor:
            futuros = {executor.submit(procesar_un_mes, p): p for p in periodos}
            for fut in as_completed(futuros):
                p = futuros[fut]
                res = fut.result()

print("\n==========================================================")
print("Glue Job finalizado con éxito.")
print("==========================================================")
job.commit()
