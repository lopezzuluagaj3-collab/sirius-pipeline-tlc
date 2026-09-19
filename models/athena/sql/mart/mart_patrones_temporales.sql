-- =============================================================================
-- DATA MART 4: PATRONES TEMPORALES, ESTACIONALIDAD Y HORAS PICO
-- =============================================================================
-- PREGUNTA DE NEGOCIO:
-- ¿Cómo se distribuye la demanda de transporte en NYC a lo largo de las 24 horas
-- del día y los 7 días de la semana?
-- ¿Cuáles son las horas pico matutinas y vespertinas?
-- ¿Cómo varía el comportamiento de los usuarios en días laborales vs fines de semana?
-- ¿Se evidencia una demanda nocturna diferente entre taxis amarillos y Uber/Lyft?
--
-- GRANULARIDAD:
-- Anual por servicio, día de la semana y hora del día
-- (anio, tipo_servicio, dia_semana_num, dia_semana_nombre, hora_dia).
--
-- ORIGEN:
-- - ${staging_db}.taxi
-- - ${staging_db}.fhvhv
--
-- OPTIMIZACIÓN:
-- Materializada en Parquet Snappy en S3 Mart para gráficos de calor y series temporales en Power BI.
-- =============================================================================

CREATE TABLE ${mart_db}.mart_patrones_temporales
WITH (
  format = 'PARQUET',
  parquet_compression = 'SNAPPY',
  external_location = 's3://${mart_bucket}/mart/mart_patrones_temporales/'
) AS
WITH viajes_taxi AS (
  SELECT
    anio,
    tipo_taxi AS tipo_servicio,
    day_of_week(pickup_datetime) AS dia_semana_num,
    date_format(pickup_datetime, '%W') AS dia_semana_nombre,
    hour(pickup_datetime) AS hora_dia,
    fare_amount AS tarifa,
    trip_distance AS distancia
  FROM ${staging_db}.taxi
  WHERE pickup_datetime IS NOT NULL
    AND trip_distance > 0
    AND fare_amount > 0
),
viajes_fhvhv AS (
  SELECT
    anio,
    'fhvhv' AS tipo_servicio,
    day_of_week(pickup_datetime) AS dia_semana_num,
    date_format(pickup_datetime, '%W') AS dia_semana_nombre,
    hour(pickup_datetime) AS hora_dia,
    base_passenger_fare AS tarifa,
    trip_miles AS distancia
  FROM ${staging_db}.fhvhv
  WHERE pickup_datetime IS NOT NULL
    AND trip_miles > 0
    AND base_passenger_fare > 0
),
unificado AS (
  SELECT * FROM viajes_taxi
  UNION ALL
  SELECT * FROM viajes_fhvhv
)
SELECT
  anio,
  tipo_servicio,
  dia_semana_num,
  dia_semana_nombre,
  hora_dia,
  COUNT(*) AS total_viajes,
  ROUND(AVG(tarifa), 2) AS tarifa_promedio,
  ROUND(AVG(distancia), 2) AS distancia_promedio_millas
FROM unificado
GROUP BY
  anio,
  tipo_servicio,
  dia_semana_num,
  dia_semana_nombre,
  hora_dia
ORDER BY
  anio,
  tipo_servicio,
  dia_semana_num,
  hora_dia;
