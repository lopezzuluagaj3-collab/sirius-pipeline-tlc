-- =============================================================================
-- DATA MART 3: DEMANDA TERRITORIAL Y FLUJOS DE MOVILIDAD (NYC TLC ZONES)
-- =============================================================================
-- PREGUNTA DE NEGOCIO:
-- ¿Cuáles son los principales corredores y patrones de movilidad urbana en NYC?
-- ¿Cuáles distritos (Boroughs) y zonas generan y atraen la mayor cantidad de viajes?
-- ¿Cómo difieren los flujos territoriales entre taxis tradicionales y apps (FHVHV)?
-- ¿Cuáles son los corredores hacia los aeropuertos principales (JFK, LaGuardia, EWR)?
--
-- GRANULARIDAD:
-- Anual por servicio, distrito/zona de origen y destino
-- (anio, tipo_servicio, pu_borough, pu_zone, do_borough, do_zone).
--
-- ORIGEN:
-- - ${staging_db}.taxi (2016 en adelante, cuando TLC adoptó LocationIDs de zona)
-- - ${staging_db}.fhvhv (2019 en adelante)
-- - ${staging_db}.taxi_zone_lookup (Tabla dimensional oficial TLC)
--
-- OPTIMIZACIÓN:
-- Materializada en Parquet Snappy en S3 Mart para mapeo y visualización en Power BI.
-- =============================================================================

CREATE TABLE ${mart_db}.mart_demanda_territorial
WITH (
  format = 'PARQUET',
  parquet_compression = 'SNAPPY',
  external_location = 's3://${mart_bucket}/mart/mart_demanda_territorial/'
) AS
WITH viajes_unificados AS (
  -- Taxis (Yellow y Green) desde 2016 con LocationID válido
  SELECT
    anio,
    tipo_taxi AS tipo_servicio,
    pulocationid,
    dolocationid,
    trip_distance AS millas,
    total_amount AS monto
  FROM ${staging_db}.taxi
  WHERE anio >= '2016'
    AND pulocationid IS NOT NULL
    AND dolocationid IS NOT NULL

  UNION ALL

  -- Apps de Movilidad (FHVHV: Uber, Lyft, Via)
  SELECT
    anio,
    'fhvhv' AS tipo_servicio,
    pulocationid,
    dolocationid,
    trip_miles AS millas,
    (base_passenger_fare + tolls + bcf + sales_tax + congestion_surcharge + airport_fee + tips) AS monto
  FROM ${staging_db}.fhvhv
  WHERE pulocationid IS NOT NULL
    AND dolocationid IS NOT NULL
)
SELECT
  v.anio,
  v.tipo_servicio,
  COALESCE(pu.Borough, 'Unknown') AS pu_borough,
  COALESCE(pu.Zone, 'Unknown') AS pu_zone,
  COALESCE(do.Borough, 'Unknown') AS do_borough,
  COALESCE(do.Zone, 'Unknown') AS do_zone,
  COUNT(*) AS total_viajes,
  ROUND(AVG(v.millas), 2) AS distancia_promedio_millas,
  ROUND(SUM(v.monto), 2) AS monto_total
FROM viajes_unificados v
LEFT JOIN ${staging_db}.taxi_zone_lookup pu ON v.pulocationid = TRY_CAST(pu.locationid AS BIGINT)
LEFT JOIN ${staging_db}.taxi_zone_lookup do ON v.dolocationid = TRY_CAST(do.locationid AS BIGINT)
GROUP BY
  v.anio,
  v.tipo_servicio,
  COALESCE(pu.Borough, 'Unknown'),
  COALESCE(pu.Zone, 'Unknown'),
  COALESCE(do.Borough, 'Unknown'),
  COALESCE(do.Zone, 'Unknown');
