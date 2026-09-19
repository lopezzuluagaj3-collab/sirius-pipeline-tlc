# Base de datos de Glue Data Catalog para la capa row
resource "aws_glue_catalog_database" "row" {
  name        = "${var.project_name}_row_db"
  description = "Base de datos de metadatos para la capa row de NYC TLC"
}

# Workgroup de Athena dedicado para EDA
resource "aws_athena_workgroup" "eda" {
  name        = "${var.project_name}-eda"
  description = "Workgroup de Athena para Analisis Exploratorio de Datos (EDA)"
  state       = "ENABLED"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.mart_bucket_name}/result_eda/"
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}

# -------------------------------------------------------------
# Tabla 1: Yellow Taxi
# -------------------------------------------------------------
resource "aws_glue_catalog_table" "yellow" {
  name          = "yellow"
  database_name = aws_glue_catalog_database.row.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"                  = "TRUE"
    "parquet.compression"       = "SNAPPY"
    "classification"            = "parquet"
    "projection.enabled"        = "true"
    "projection.anio.type"      = "integer"
    "projection.anio.range"     = "2009,2030"
    "projection.mes.type"       = "integer"
    "projection.mes.range"      = "1,12"
    "projection.mes.digits"     = "2"
    "storage.location.template" = "s3://${var.row_bucket_name}/row/yellow/anio=$${anio}/mes=$${mes}"
  }

  partition_keys {
    name = "anio"
    type = "string"
  }
  partition_keys {
    name = "mes"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${var.row_bucket_name}/row/yellow/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "yellow-parquet-serde"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "vendorid"
      type = "int"
    }
    columns {
      name = "tpep_pickup_datetime"
      type = "timestamp"
    }
    columns {
      name = "tpep_dropoff_datetime"
      type = "timestamp"
    }
    columns {
      name = "passenger_count"
      type = "bigint"
    }
    columns {
      name = "trip_distance"
      type = "double"
    }
    columns {
      name = "ratecodeid"
      type = "bigint"
    }
    columns {
      name = "store_and_fwd_flag"
      type = "string"
    }
    columns {
      name = "pulocationid"
      type = "int"
    }
    columns {
      name = "dolocationid"
      type = "int"
    }
    columns {
      name = "payment_type"
      type = "bigint"
    }
    columns {
      name = "fare_amount"
      type = "double"
    }
    columns {
      name = "extra"
      type = "double"
    }
    columns {
      name = "mta_tax"
      type = "double"
    }
    columns {
      name = "tip_amount"
      type = "double"
    }
    columns {
      name = "tolls_amount"
      type = "double"
    }
    columns {
      name = "improvement_surcharge"
      type = "double"
    }
    columns {
      name = "total_amount"
      type = "double"
    }
    columns {
      name = "congestion_surcharge"
      type = "double"
    }
    columns {
      name = "airport_fee"
      type = "double"
    }
  }
}

# -------------------------------------------------------------
# Tabla 2: Green Taxi
# -------------------------------------------------------------
resource "aws_glue_catalog_table" "green" {
  name          = "green"
  database_name = aws_glue_catalog_database.row.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"                  = "TRUE"
    "parquet.compression"       = "SNAPPY"
    "classification"            = "parquet"
    "projection.enabled"        = "true"
    "projection.anio.type"      = "integer"
    "projection.anio.range"     = "2009,2030"
    "projection.mes.type"       = "integer"
    "projection.mes.range"      = "1,12"
    "projection.mes.digits"     = "2"
    "storage.location.template" = "s3://${var.row_bucket_name}/row/green/anio=$${anio}/mes=$${mes}"
  }

  partition_keys {
    name = "anio"
    type = "string"
  }
  partition_keys {
    name = "mes"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${var.row_bucket_name}/row/green/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "green-parquet-serde"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "vendorid"
      type = "int"
    }
    columns {
      name = "lpep_pickup_datetime"
      type = "timestamp"
    }
    columns {
      name = "lpep_dropoff_datetime"
      type = "timestamp"
    }
    columns {
      name = "store_and_fwd_flag"
      type = "string"
    }
    columns {
      name = "ratecodeid"
      type = "bigint"
    }
    columns {
      name = "pulocationid"
      type = "int"
    }
    columns {
      name = "dolocationid"
      type = "int"
    }
    columns {
      name = "passenger_count"
      type = "bigint"
    }
    columns {
      name = "trip_distance"
      type = "double"
    }
    columns {
      name = "fare_amount"
      type = "double"
    }
    columns {
      name = "extra"
      type = "double"
    }
    columns {
      name = "mta_tax"
      type = "double"
    }
    columns {
      name = "tip_amount"
      type = "double"
    }
    columns {
      name = "tolls_amount"
      type = "double"
    }
    columns {
      name = "ehail_fee"
      type = "double"
    }
    columns {
      name = "improvement_surcharge"
      type = "double"
    }
    columns {
      name = "total_amount"
      type = "double"
    }
    columns {
      name = "payment_type"
      type = "bigint"
    }
    columns {
      name = "trip_type"
      type = "bigint"
    }
    columns {
      name = "congestion_surcharge"
      type = "double"
    }
  }
}

# -------------------------------------------------------------
# Tabla 3: For-Hire Vehicles (FHV)
# -------------------------------------------------------------
resource "aws_glue_catalog_table" "fhv" {
  name          = "fhv"
  database_name = aws_glue_catalog_database.row.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"                  = "TRUE"
    "parquet.compression"       = "SNAPPY"
    "classification"            = "parquet"
    "projection.enabled"        = "true"
    "projection.anio.type"      = "integer"
    "projection.anio.range"     = "2009,2030"
    "projection.mes.type"       = "integer"
    "projection.mes.range"      = "1,12"
    "projection.mes.digits"     = "2"
    "storage.location.template" = "s3://${var.row_bucket_name}/row/fhv/anio=$${anio}/mes=$${mes}"
  }

  partition_keys {
    name = "anio"
    type = "string"
  }
  partition_keys {
    name = "mes"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${var.row_bucket_name}/row/fhv/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "fhv-parquet-serde"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "dispatching_base_num"
      type = "string"
    }
    columns {
      name = "pickup_datetime"
      type = "timestamp"
    }
    columns {
      name = "dropoff_datetime"
      type = "timestamp"
    }
    columns {
      name = "pulocationid"
      type = "bigint"
    }
    columns {
      name = "dolocationid"
      type = "bigint"
    }
    columns {
      name = "sr_flag"
      type = "bigint"
    }
    columns {
      name = "affiliated_base_number"
      type = "string"
    }
  }
}

# -------------------------------------------------------------
# Tabla 4: High-Volume For-Hire Vehicles (FHVHV: Uber/Lyft)
# -------------------------------------------------------------
resource "aws_glue_catalog_table" "fhvhv" {
  name          = "fhvhv"
  database_name = aws_glue_catalog_database.row.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"                  = "TRUE"
    "parquet.compression"       = "SNAPPY"
    "classification"            = "parquet"
    "projection.enabled"        = "true"
    "projection.anio.type"      = "integer"
    "projection.anio.range"     = "2009,2030"
    "projection.mes.type"       = "integer"
    "projection.mes.range"      = "1,12"
    "projection.mes.digits"     = "2"
    "storage.location.template" = "s3://${var.row_bucket_name}/row/fhvhv/anio=$${anio}/mes=$${mes}"
  }

  partition_keys {
    name = "anio"
    type = "string"
  }
  partition_keys {
    name = "mes"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${var.row_bucket_name}/row/fhvhv/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "fhvhv-parquet-serde"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "hvfhs_license_num"
      type = "string"
    }
    columns {
      name = "dispatching_base_num"
      type = "string"
    }
    columns {
      name = "originating_base_num"
      type = "string"
    }
    columns {
      name = "request_datetime"
      type = "timestamp"
    }
    columns {
      name = "on_scene_datetime"
      type = "timestamp"
    }
    columns {
      name = "pickup_datetime"
      type = "timestamp"
    }
    columns {
      name = "dropoff_datetime"
      type = "timestamp"
    }
    columns {
      name = "pulocationid"
      type = "int"
    }
    columns {
      name = "dolocationid"
      type = "int"
    }
    columns {
      name = "trip_miles"
      type = "double"
    }
    columns {
      name = "trip_time"
      type = "bigint"
    }
    columns {
      name = "base_passenger_fare"
      type = "double"
    }
    columns {
      name = "tolls"
      type = "double"
    }
    columns {
      name = "bcf"
      type = "double"
    }
    columns {
      name = "sales_tax"
      type = "double"
    }
    columns {
      name = "congestion_surcharge"
      type = "double"
    }
    columns {
      name = "airport_fee"
      type = "double"
    }
    columns {
      name = "tips"
      type = "double"
    }
    columns {
      name = "driver_pay"
      type = "double"
    }
    columns {
      name = "shared_request_flag"
      type = "string"
    }
    columns {
      name = "shared_match_flag"
      type = "string"
    }
    columns {
      name = "access_a_ride_flag"
      type = "string"
    }
    columns {
      name = "wav_request_flag"
      type = "string"
    }
    columns {
      name = "wav_match_flag"
      type = "string"
    }
  }
}

# =============================================================
# CAPA STAGING (SILVER) - Base de Datos y Tablas Externas Athena
# =============================================================

resource "aws_glue_catalog_database" "staging" {
  name        = "${var.project_name}_staging_db"
  description = "Base de datos de metadatos para la capa Staging (Silver) de NYC TLC"
}

# -------------------------------------------------------------
# Tabla Staging 1: Taxi (Yellow + Green unificados)
# -------------------------------------------------------------
resource "aws_glue_catalog_table" "staging_taxi" {
  name          = "taxi"
  database_name = aws_glue_catalog_database.staging.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"                    = "TRUE"
    "parquet.compression"         = "SNAPPY"
    "classification"              = "parquet"
    "projection.enabled"          = "true"
    "projection.tipo_taxi.type"   = "enum"
    "projection.tipo_taxi.values" = "yellow,green"
    "projection.anio.type"        = "integer"
    "projection.anio.range"       = "2009,2030"
    "projection.mes.type"         = "integer"
    "projection.mes.range"        = "1,12"
    "projection.mes.digits"       = "2"
    "storage.location.template"   = "s3://${var.staging_bucket_name}/staging/taxi/tipo_taxi=$${tipo_taxi}/anio=$${anio}/mes=$${mes}"
  }

  partition_keys {
    name = "tipo_taxi"
    type = "string"
  }
  partition_keys {
    name = "anio"
    type = "string"
  }
  partition_keys {
    name = "mes"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${var.staging_bucket_name}/staging/taxi/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "taxi-parquet-serde"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "vendorid"
      type = "bigint"
    }
    columns {
      name = "pickup_datetime"
      type = "timestamp"
    }
    columns {
      name = "dropoff_datetime"
      type = "timestamp"
    }
    columns {
      name = "passenger_count"
      type = "bigint"
    }
    columns {
      name = "trip_distance"
      type = "double"
    }
    columns {
      name = "pickup_longitude"
      type = "double"
    }
    columns {
      name = "pickup_latitude"
      type = "double"
    }
    columns {
      name = "ratecodeid"
      type = "bigint"
    }
    columns {
      name = "store_and_fwd_flag"
      type = "string"
    }
    columns {
      name = "dropoff_longitude"
      type = "double"
    }
    columns {
      name = "dropoff_latitude"
      type = "double"
    }
    columns {
      name = "payment_type"
      type = "bigint"
    }
    columns {
      name = "fare_amount"
      type = "double"
    }
    columns {
      name = "extra"
      type = "double"
    }
    columns {
      name = "mta_tax"
      type = "double"
    }
    columns {
      name = "tip_amount"
      type = "double"
    }
    columns {
      name = "tolls_amount"
      type = "double"
    }
    columns {
      name = "total_amount"
      type = "double"
    }
    columns {
      name = "pulocationid"
      type = "bigint"
    }
    columns {
      name = "dolocationid"
      type = "bigint"
    }
    columns {
      name = "trip_type"
      type = "bigint"
    }
    columns {
      name = "improvement_surcharge"
      type = "double"
    }
    columns {
      name = "congestion_surcharge"
      type = "double"
    }
    columns {
      name = "airport_fee"
      type = "double"
    }
    columns {
      name = "ehail_fee"
      type = "double"
    }
  }
}

# -------------------------------------------------------------
# Tabla Staging 2: FHVHV (Uber, Lyft, Via)
# -------------------------------------------------------------
resource "aws_glue_catalog_table" "staging_fhvhv" {
  name          = "fhvhv"
  database_name = aws_glue_catalog_database.staging.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"                  = "TRUE"
    "parquet.compression"       = "SNAPPY"
    "classification"            = "parquet"
    "projection.enabled"        = "true"
    "projection.anio.type"      = "integer"
    "projection.anio.range"     = "2019,2030"
    "projection.mes.type"       = "integer"
    "projection.mes.range"      = "1,12"
    "projection.mes.digits"     = "2"
    "storage.location.template" = "s3://${var.staging_bucket_name}/staging/fhvhv/anio=$${anio}/mes=$${mes}"
  }

  partition_keys {
    name = "anio"
    type = "string"
  }
  partition_keys {
    name = "mes"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${var.staging_bucket_name}/staging/fhvhv/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "fhvhv-parquet-serde"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "hvfhs_license_num"
      type = "string"
    }
    columns {
      name = "dispatching_base_num"
      type = "string"
    }
    columns {
      name = "originating_base_num"
      type = "string"
    }
    columns {
      name = "request_datetime"
      type = "timestamp"
    }
    columns {
      name = "on_scene_datetime"
      type = "timestamp"
    }
    columns {
      name = "pickup_datetime"
      type = "timestamp"
    }
    columns {
      name = "dropoff_datetime"
      type = "timestamp"
    }
    columns {
      name = "pulocationid"
      type = "bigint"
    }
    columns {
      name = "dolocationid"
      type = "bigint"
    }
    columns {
      name = "trip_miles"
      type = "double"
    }
    columns {
      name = "trip_time"
      type = "bigint"
    }
    columns {
      name = "base_passenger_fare"
      type = "double"
    }
    columns {
      name = "tolls"
      type = "double"
    }
    columns {
      name = "bcf"
      type = "double"
    }
    columns {
      name = "sales_tax"
      type = "double"
    }
    columns {
      name = "congestion_surcharge"
      type = "double"
    }
    columns {
      name = "airport_fee"
      type = "double"
    }
    columns {
      name = "tips"
      type = "double"
    }
    columns {
      name = "driver_pay"
      type = "double"
    }
    columns {
      name = "shared_request_flag"
      type = "string"
    }
    columns {
      name = "shared_match_flag"
      type = "string"
    }
    columns {
      name = "access_a_ride_flag"
      type = "string"
    }
    columns {
      name = "wav_request_flag"
      type = "string"
    }
    columns {
      name = "wav_match_flag"
      type = "int"
    }
  }
}

# -------------------------------------------------------------
# Tabla Staging 3: FHV (Bases tradicionales / Livery)
# -------------------------------------------------------------
resource "aws_glue_catalog_table" "staging_fhv" {
  name          = "fhv"
  database_name = aws_glue_catalog_database.staging.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"                  = "TRUE"
    "parquet.compression"       = "SNAPPY"
    "classification"            = "parquet"
    "projection.enabled"        = "true"
    "projection.anio.type"      = "integer"
    "projection.anio.range"     = "2015,2030"
    "projection.mes.type"       = "integer"
    "projection.mes.range"      = "1,12"
    "projection.mes.digits"     = "2"
    "storage.location.template" = "s3://${var.staging_bucket_name}/staging/fhv/anio=$${anio}/mes=$${mes}"
  }

  partition_keys {
    name = "anio"
    type = "string"
  }
  partition_keys {
    name = "mes"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${var.staging_bucket_name}/staging/fhv/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "fhv-parquet-serde"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "dispatching_base_num"
      type = "string"
    }
    columns {
      name = "pickup_datetime"
      type = "timestamp"
    }
    columns {
      name = "dropoff_datetime"
      type = "timestamp"
    }
    columns {
      name = "pulocationid"
      type = "bigint"
    }
    columns {
      name = "dolocationid"
      type = "bigint"
    }
    columns {
      name = "sr_flag"
      type = "bigint"
    }
    columns {
      name = "affiliated_base_number"
      type = "string"
    }
  }
}
