-- =============================================================================
-- DATA MART 2: KPIS FINANCIEROS Y RENDIMIENTO ECONÓMICO
-- =============================================================================
-- PREGUNTA DE NEGOCIO:
-- ¿Cuál es el comportamiento económico y la estructura de costos del transporte
-- de pasajeros en Nueva York? ¿Cómo difieren las tarifas promedio, propinas,
-- recargos por congestión e ingresos de los conductores entre Taxis y FHVHV?
-- ¿Cuál es la rentabilidad por milla y por minuto de viaje?
--
-- GRANULARIDAD:
-- Mensual por tipo de servicio (anio, mes, tipo_servicio).
--
-- ORIGEN:
-- - ${staging_db}.taxi
-- - ${staging_db}.fhvhv
--
-- REGLAS DE NEGOCIO:
-- Se excluyen viajes con distancias <= 0 o tarifas no positivas para evitar
-- distorsiones por reembolsos o anomalías de medición.
-- Se calcula la duración promedio en minutos a partir de pickup y dropoff.
--
-- OPTIMIZACIÓN:
-- Materializada en formato Parquet Snappy en S3 Mart para carga analítica en Power BI.
-- =============================================================================

CREATE TABLE ${mart_db}.mart_kpis_financieros
WITH (
  format = 'PARQUET',
  parquet_compression = 'SNAPPY',
  external_location = 's3://${mart_bucket}/mart/mart_kpis_financieros/'
) AS
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
  FROM ${staging_db}.taxi
  WHERE trip_distance > 0
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
  FROM ${staging_db}.fhvhv
  WHERE trip_miles > 0
    AND base_passenger_fare > 0
    AND trip_time > 0
  GROUP BY anio, mes
)
SELECT * FROM kpis_taxi
UNION ALL
SELECT * FROM kpis_fhvhv
ORDER BY anio, mes, tipo_servicio;
