-- =============================================================================
-- DATA MART 1: CUOTA DE MERCADO MENSUAL (2009 - 2026)
-- =============================================================================
-- PREGUNTA DE NEGOCIO:
-- ¿Cómo ha evolucionado la cuota de mercado del transporte de pasajeros en NYC
-- entre Taxis Tradicionales (Yellow y Green), Bases Livery (FHV) y Aplicaciones
-- de Movilidad (Uber, Lyft, Via - FHVHV) a lo largo de los últimos 18 años?
-- ¿En qué fecha las aplicaciones superaron a los taxis amarillos en volumen?
-- ¿Cuál fue el impacto estructural de la pandemia de COVID-19 en 2020?
--
-- GRANULARIDAD:
-- Mensual por tipo de servicio (anio, mes, tipo_servicio).
--
-- ORIGEN:
-- - ${staging_db}.taxi (Yellow y Green)
-- - ${staging_db}.fhvhv (High Volume FHV)
-- - ${staging_db}.fhv (For-Hire Vehicles tradicionales)
--
-- OPTIMIZACIÓN:
-- Materializada en formato Parquet Snappy en S3 Mart para lectura sub-segundo en Power BI.
-- =============================================================================

CREATE TABLE ${mart_db}.mart_cuota_mercado_mensual
WITH (
  format = 'PARQUET',
  parquet_compression = 'SNAPPY',
  external_location = 's3://${mart_bucket}/mart/mart_cuota_mercado_mensual/'
) AS
WITH viajes_por_servicio AS (
  -- Taxis (Yellow y Green)
  SELECT
    anio,
    mes,
    tipo_taxi AS tipo_servicio,
    COUNT(*) AS total_viajes
  FROM ${staging_db}.taxi
  GROUP BY anio, mes, tipo_taxi

  UNION ALL

  -- Aplicaciones de Movilidad (FHVHV: Uber, Lyft, Via)
  SELECT
    anio,
    mes,
    'fhvhv' AS tipo_servicio,
    COUNT(*) AS total_viajes
  FROM ${staging_db}.fhvhv
  GROUP BY anio, mes

  UNION ALL

  -- Bases Tradicionales (FHV)
  SELECT
    anio,
    mes,
    'fhv' AS tipo_servicio,
    COUNT(*) AS total_viajes
  FROM ${staging_db}.fhv
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
