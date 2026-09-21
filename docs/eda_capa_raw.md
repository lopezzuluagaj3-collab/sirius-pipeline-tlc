# Documentación Técnica: Análisis Exploratorio de Datos (EDA) — Capa Raw (Bronce)
**Proyecto Sirius — NYC TLC Data Pipeline**  
**Autor:** Juan (Data Engineering)  
**Entorno de Datos:** AWS Athena (Serverless SQL / Presto), DuckDB 1.5.5, AWS S3  
**Alcance Histórico:** 2009-01 a 2026-07 (590 archivos Parquet, ~4,376 Millones de Registros)

---

## 1. Introducción y Contexto Arquitectónico

El proyecto **Sirius** procesa el histórico completo de transporte de la ciudad de Nueva York (New York City Taxi and Limousine Commission - NYC TLC). En su versión reformada, el pipeline eliminó las capas intermedias obsoletas de staging/mart y consolidó una arquitectura de dos etapas de procesamiento:
1. **Capa Raw (Bronce):** Almacenamiento inmutable en Amazon S3 (`s3://sirius-row-603437461408/row/<formato>/anio=YYYY/mes=MM/`) con esquemas externos catalogados en AWS Glue mediante **Partition Projection**.
2. **Capa Clean / Silver (en desarrollo):** Transformación y estandarización distribuida ejecutada en **AWS Glue (PySpark)**.

### Objetivo del EDA
El propósito del EDA sobre la capa raw no fue realizar estadísticas descriptivas superficiales, sino **descubrir y caracterizar las patologías de datos, anomalías de esquema, sesgos de captura y mutaciones regulatorias** presentes en 17 años de ingesta heterogénea. El entregable final es la **Matriz de Hallazgos \(\rightarrow\) Reglas de Limpieza**, que gobierna la lógica del Glue Job.

### Volumen Analizado por Formato
| Formato | Cobertura Temporal | Total Archivos Parquet | Filas Totales | Esquema Clave |
|---|---|---|---|---|
| **Yellow Taxi** | 2009-01 a 2026-07 | 211 | 1,853,446,000 | Taxímetro regulado tradicional |
| **Green Taxi** | 2014-01 a 2026-07 | 151 | 84,213,000 | Taxis de distritos periféricos (Boroughs) |
| **FHV (For-Hire)** | 2015-01 a 2026-06 | 138 | 807,249,000 | Bases de despacho comunitarias / Livery |
| **FHVHV (High Volume)** | 2019-02 a 2026-07 | 90 | 1,628,495,000 | Aplicaciones (Uber, Lyft, Via, Juno) |
| **Total Flota NYC** | **2009–2026** | **590** | **~4,376,000,000** | **4 esquemas distintos en evolución** |

---

## 2. Metodología y Herramientas del EDA

Para evaluar más de 4.3 billones de filas sin costos prohibitivos ni saturación de memoria, se combinaron dos motores:
1. **AWS Athena (Presto / Trino):** Consultas distribuidas particionadas usando *Partition Projection* (`anio` 2009–2030, `mes` 1–12 como strings). Esto permitió podar particiones en segundos y evaluar agregaciones masivas en S3.
2. **DuckDB local (1.5.5):** Inspección a nivel de metadatos de archivos Parquet individuales en S3 vía secret `CREDENTIAL_CHAIN`, para auditar tipos físicos (`PHYSICAL_TYPE`) y esquemas internos sin depender de Athena.

---

## 3. Hallazgos Empíricos Detallados por Dimensión

### 3.1. Deriva de Esquemas y Choques de Tipos (Schema Drift)
Uno de los problemas más críticos descubiertos es que **ninguna declaración estática de DDL en Glue/Athena puede leer todo el histórico de Parquet sin romperse**. 

#### Evidencia Empírica de Choques (`HIVE_BAD_DATA`):
- **`yellow`**:
  - `passenger_count`: En mayo de 2020 (`2020-05`), el tipo Parquet es `DOUBLE`, incompatible con el `bigint` declarado.
  - `payment_type`: En enero de 2009 (`2009-01`), el tipo Parquet es `BINARY` (strings como `'CAS'`, `'CRD'`), chocando con `bigint`.
  - `ratecodeid`: En abril de 2019 (`2019-04`) y abril de 2021 (`2021-04`), el tipo Parquet muta a `DOUBLE`.
- **`green`**:
  - `passenger_count`: En noviembre de 2021 (`2021-11`), Parquet almacena `DOUBLE` frente a `bigint`.
  - `payment_type`: En octubre de 2020 (`2020-10`), muta a `DOUBLE` frente a `bigint`.
- **`fhv`**:
  - `pulocationid`: En junio de 2020 (`2020-06`), viene como `DOUBLE`.
  - `dolocationid`: En noviembre de 2022 (`2022-11`), viene como `DOUBLE`.
- **`fhvhv`**:
  - `airport_fee`: Migró de `INT32` a `DOUBLE`. Al ser una ampliación de tipo (*type widening*), Athena lo soporta sin fallar.
  - `wav_match_flag`: Alterna entre numérico y string; Athena no falla pero devuelve `NULL` silencioso.

#### Causa Raíz Técnica:
La TLC migró sus scripts de ingesta en varias épocas usando librerías de Python (como pandas antiguo sin soporte de tipos enteros anulables `Int64`). Al serializar un DataFrame con valores nulos (`NaN`), pandas convierte automáticamente toda la columna entera a `float64` (`DOUBLE`). Al intentar leerlo contra un esquema Hive estricto de `bigint`, Athena no puede aplicar un estrechamiento de tipo (*narrowing*) y falla inmediatamente antes de procesar cualquier cláusula SQL (incluso con `CAST`).

---

### 3.2. Integridad Temporal y Valores Centinela

#### Inversión de Fechas (`dropoff_datetime < pickup_datetime`):
- En **yellow** y **green**, las carreras donde la bajada del pasajero ocurre antes de la subida están concentradas de forma anómala en un proveedor específico: **VendorID = 6**.
- En yellow, Vendor 6 arranca abruptamente en septiembre de 2020 (`2020-09`) y desaparece a finales de 2021. En green, reaparece con un pico masivo entre febrero y junio de 2025.
- La gran mayoría de los viajes de Vendor 6 registran incoherencias temporales sistemáticas (taxímetros descalibrados o zonas horarias no convertidas).

#### El Centinela de FHV (`1989-01-01 00:00:00`):
- En las bases de despacho de FHV durante los años 2015 y 2016, se identificaron **195,500,741 filas** donde `dropoff_datetime` es exactamente `'1989-01-01 00:00:00'`.
- **Diagnóstico:** No corresponde a un viaje con inversión de fechas ni a un error de cálculo, sino a un **valor centinela** fijado por las bases de despacho tradicionales para indicar *"viaje sin registro de fin / bajada no reportada"*. Tratarlo como fecha real distorsiona métricas de duración; debe tratarse formalmente como `NULL`.

#### Desbordes de Partición:
- Se identificó un desborde legítimo: carreras iniciadas el 31 de diciembre a las 23:xx que finalizan el 1 de enero a las 00:xx tienen \(\text{anio\_real} = \text{anio} + 1\). El volumen de este desborde es proporcional al volumen anual y cayó en 2020 por confinamiento de COVID-19.
- Cualquier año menor a 2009 o mayor a 2026 (por ejemplo, carreras con año 2002 en yellow 2022-06, o fechas del año 2088) es corrupción de reloj y debe ser descartado.

---

### 3.3. Duplicados Exactos y Filas Placeholder

| Formato | Diagnóstico de Duplicidad | Comportamiento Identificado |
|---|---|---|
| **Yellow** | Ruido bajo (<0.01%) | Salvo en **enero de 2020 (2020-01)**: Vendor 2 presentó un pico de 12,950 grupos duplicados concentrados exclusivamente entre el 6 y el 12 de enero (reingesta de lote duplicado por error operativo). |
| **Green** | Placeholder sistémico | Duplicados con alta frecuencia (hasta 146 repeticiones de la misma fila en 2014-08 y 73 en 2016-08) corresponden a **filas fantasma**: `trip_distance = 0`, tarifa mínima base (\$2.50) y zonas 264/265 ("Desconocido"). |
| **FHV** | Quiebre estructural | La tasa de duplicados se desploma **70 veces** entre mayo de 2017 (~6.6%) y junio de 2017 (~0.1%), sin alteración en el volumen de viajes. Se distribuye en más de 15 bases distintas, confirmando una reforma en el pipeline interno de TLC. |
| **FHVHV** | Altísima limpieza | Máxima repetición observada = 2, con proporciones despreciables frente a 1.6 billones de viajes. |

---

### 3.4. Montos Negativos y Rangos Raros

El análisis de `fare_amount`, `total_amount`, sobretasas y propinas arrojó patrones reveladores:

#### Pre-filtrado Upstream por la TLC (2009, 2011 y 2012):
- **2011 y 2012** tienen **exactamente 0 montos negativos** y **0 ceros** en `fare_amount` y `total_amount` (sobre 170M+ filas por año). El valor mínimo absoluto es exactamente **`2.50`**.
- **Conclusión:** La TLC aplicó un filtro estricto aguas arriba (`WHERE fare_amount >= 2.50`, la tarifa base legal) antes de publicar los archivos de 2011 y 2012. 
- En **2009**, el mínimo es exactamente `0.0`, evidenciando otro pre-filtro upstream (`fare_amount >= 0.0`).

#### Desbordes Numéricos (2010):
- En yellow 2010, el mínimo registrado es **`-2.14748E7`** (aproximadamente \(-2^{31}\)), lo que demuestra errores de subdesbordamiento de enteros (*integer underflow*) serializados en columnas flotantes.

#### El Patrón de Reverso en Efectivo de Vendor 2 (2015–2026):
- Se descubrieron **579,713 carreras con tarifa negativa en efectivo (`payment_type = 2`)**.
- **Hallazgo 100% excluyente:** El **100.00%** de estos registros pertenece a **VendorID = 2 (VeriFone)**. Vendor 1 (CMT) tiene exactamente 0 casos.
- La serie temporal demuestra que no fue un error aislado de 2025, sino una práctica contable que creció exponencialmente:
  - 2017: 367 casos
  - 2019: 20,762 casos
  - 2022: 54,220 casos
  - 2024: 144,430 casos
  - 2025: 186,208 casos
- **Naturaleza:** Corresponde a notas de crédito / reversos de cobro de taxímetro emitidos por el software de VeriFone donde todos los componentes monetarios se asientan con signo negativo.

#### Distancias Negativas en 2019 y 2020:
- En yellow y green, la variable de distancia (`trip_distance < 0`) **solo existe en 2019 (9,102 en yellow, 18,705 en green) y 2020 (2,338 en yellow, 822 en green)**. En todos los demás años de la historia (2009-2018 y 2021-2026) hay exactamente 0 distancias negativas. Es un defecto cruzado del software de captura de la TLC durante esos dos años.

#### Métricas Físicas y Salarios en FHVHV:
- En **1,628 millones de viajes de Uber/Lyft**, las variables físicas y de servicio son impecables: `tips`, `trip_miles` y `trip_time` tienen **0 valores negativos**.
- Sin embargo, **36,565,930 filas (2.25%) tienen `driver_pay = 0`**.
- **Desglose por plataforma:**
  - **Via (HV0004):** **86.9%** de sus viajes tienen `driver_pay = 0` (12.07M de 13.88M).
  - **Lyft (HV0005):** 4.27% (18.4M).
  - **Uber (HV0003):** 0.51% (6.08M).
- **Causa de negocio:** Via operaba bajo un modelo de transporte compartido estilo micro-shuttle donde los choferes cobraban por horas de turno pre-pactadas, no por split/comisión de cada carrera individual.

---

### 3.5. Variables Categóricas y la Revelación de Flex Fare

#### Proveedores (VendorID):
- Oficialmente la TLC solo reconoce a `1` (CMT) y `2` (VeriFone).
- El EDA reveló la existencia de vendors no documentados que operaron en ventanas específicas:
  - **Vendor 7** (862K filas): Activo en 2024–2026. Es un nuevo proveedor piloto moderno, con 0% de nulos y datos muy limpios.
  - **Vendor 4** (758K filas): Activo en 2018–2019.
  - **Vendor 6** (316K filas): Activo en 2020–2026. Responsable de fechas invertidas y 100% de nulos en códigos de tarifa.
  - **Vendor 3** (10K filas, 2016) y **Vendor 5** (1K filas, 2018–2022).
- **2009 y 2010:** El 100% de los viajes (339.8M de filas) tiene `vendorid = NULL` en Athena. Esto se debe a que el archivo Parquet original nombraba la columna como `vendor_name` (con valores `'VTS'` y `'CMT'`), lo que producía un nulo silencioso en la tabla externa.

#### La Correlación 1:1 de Flex Fare (`payment_type = 0`):
- En yellow 2025 se observó que **11,611,894 de filas (23.8% de toda la flota anual)** tenían `ratecodeid = NULL`.
- Al cruzar contra métodos de pago, se descubrió una **correlación matemática perfecta (1:1)**:
  $$\text{ratecodeid IS NULL} \iff \text{payment_type} = 0$$
- **Explicación Regulatoria:** El código `0` representa **Flex Fare** (viajes con tarifa negociada o calculada por apps como Curb/Arro). Al no tarifar por taxímetro estándar de la ciudad (ni Standard, ni JFK, ni Newark), no se les asigna un RateCode del 1 al 6, registrándose legítimamente como `NULL`.

---

### 3.6. Cobertura Geoespacial (Zonas 264 y 265)

A partir de julio de 2016, la TLC reemplazó las coordenadas de latitud/longitud por las 263 zonas de taxi de NYC (dejando la **264** para *Unknown* y la **265** para *Outside NYC*).

| Formato | % Pickup Desconocido (264 / 265 / NULL) | % Dropoff Desconocido (264 / 265 / NULL) | Diagnóstico de Calidad Territorial |
|---|---|---|---|
| **Yellow** | **0.2% – 1.6%** | **0.6% – 1.6%** | Excelente cobertura y georreferenciación. |
| **Green** | Concentrado en placeholders | Concentrado en placeholders | Asociado a carreras basura de distancia 0. |
| **FHV** | **82.26%** (2025) | **18.60%** (2025) | **Ceguera masiva en origen:** Las bases comunitarias tradicionales no implementan telemetría GPS en tiempo real para el despacho. |
| **FHVHV** | **0.005%** (2019–2026) | **3.0% – 4.5%** (2019–2026) | **Precisión de telemetría móvil:** El origen se captura con el GPS del smartphone del cliente. El 3%–4% de destino desconocido corresponde legítimamente a bajadas fuera de NYC (Long Island, Nueva Jersey, Westchester). |

---

### 3.7. Consistencia Contable (`total_amount` vs. Suma de Componentes)

En Yellow 2025, el 79.1% de las carreras presentó discrepancias entre `total_amount` y la suma de componentes individuales:
$$\text{Diferencia} = \text{total} - (\text{fare} + \text{extra} + \text{mta} + \text{tip} + \text{tolls} + \text{improvement} + \text{congestion} + \text{airport})$$

#### Desglose Cuantitativo del Top 10 de Diferencias:
El análisis demostró que más del **95% de los descuadres** corresponden a montos exactos y discretos de la evolución tributaria y regulatoria de NYC:
1. **`+$0.75` (18,226,214 viajes):** Recargo tecnológico / procesamiento de tarjeta de crédito introducido en la última actualización de tarifas.
2. **`-$2.50` (5,565,215 viajes):** Sobretasa de congestión en Manhattan (`congestion_surcharge = $2.50`) con imputación desfasada o no desglosada por ciertos taxímetros.
3. **`-$1.75` y `+$1.75` (243,659 viajes):** Actualización de la tarifa de acceso a aeropuertos (LGA y JFK pasaron de \$1.25 a \$1.75).
4. **`+$3.25` (95,675 viajes):** Combinación exacta de Congestión (\$2.50) + Recargo (\$0.75).
5. **`-$4.25` (237,534 viajes):** Combinación exacta de Congestión (\$2.50) + Aeropuerto (\$1.75).

---

## 4. Matriz Maestra: Hallazgo del EDA \(\rightarrow\) Regla de Limpieza en Glue (PySpark)

Esta matriz constituye el requerimiento funcional directo para la construcción de los scripts de AWS Glue en la capa limpia:

| # | Dimensión | Hallazgo Empírico en Capa Raw | Regla de Limpieza / Transformación (Capa Silver) | Implementación PySpark (Glue) |
|:---:|---|---|---|---|
| **1** | **Tipos** | Columnas enteras (`passenger_count`, `ratecodeid`, `payment_type`, `pulocationid`, `dolocationid`) alternan a `DOUBLE` en varios meses por culpa de pandas con NaNs. | Cast seguro a tipo entero destino redondeando piso; no fallar si el archivo es double. Coalescer tipos. | `coalesce(col(c).cast("long"), lit(None))` |
| **2** | **Proveedores** | 2009–2010 viene 100% NULL en `vendorid` por discrepancia de nombre (`vendor_name`). Vendors no oficiales (3, 4, 5, 6, 7) en ventanas específicas. | Coalescencia de nombres antiguos y mapeo de vendors no oficiales a etiqueta común. | `coalesce(col("vendorid"), col("vendor_name"), col("vendor_id"))` y mapeo categórico. |
| **3** | **Fechas** | Inversión cronológica (`dropoff < pickup`) sistemática en Vendor 6. | Filtrar viajes válidos donde la bajada sea posterior o igual a la subida. Filas corruptas se mandan a tabla de errores. | `.filter(col("dropoff_datetime") >= col("pickup_datetime"))` |
| **4** | **Centinela FHV** | 195.5M de filas con `dropoff_datetime = '1989-01-01 00:00:00'` en FHV 2015–2016. | Reemplazar `'1989-01-01 00:00:00'` por `NULL`. Mantener el viaje si el pickup es válido. | `when(col("dropoff_datetime") == "1989-01-01 00:00:00", lit(None)).otherwise(col("dropoff_datetime"))` |
| **5** | **Particionado** | Carreras con años absurdos (2002, 2088) y desbordes normales de fin de año (\(\text{anio} + 1\)). | Filtrar viajes reales entre 2009 y 2026. Reparticionar físicamente por el año y mes real de `pickup_datetime`. | `.filter(year(col("pickup_datetime")).between(2009, 2026))` |
| **6** | **Duplicados** | Duplicados exactos por reingesta en Yellow (2020-01) y placeholders en Green (`dist=0`, zona 264). | Deduplicación por clave natural del viaje sobre el conjunto de columnas de negocio. | `.dropDuplicates(["vendorid", "pickup_datetime", "dropoff_datetime", "pulocationid", "dolocationid", "fare_amount"])` |
| **7** | **Negativos** | Tarifas negativas representan reversos contables en Vendor 2 efectivo. Distancias negativas en 2019–2020 son bug de TLC. | En viajes facturados válidos: `fare_amount >= 0` y `trip_distance >= 0`. Marcar reversos en flag `is_reversal`. | `when(col("fare_amount") < 0, lit(True)).otherwise(lit(False))` |
| **8** | **Flex Fare** | `payment_type = 0` tiene 100% de correlación con `ratecodeid = NULL`. | Etiquetar `payment_type = 0` como `'Flex Fare'` y documentar que su `ratecodeid` es nulo por diseño regulatorio. | `when(col("payment_type") == 0, "Flex Fare")` |
| **9** | **Zonas 264/265** | FHV tiene 82% de pickups ciegos (zona 264/NULL). FHVHV tiene 99.99% de pickups válidos. | **No eliminar** carreras con zona 264/265/NULL (destruiría el 82% de FHV). Imputar dimensión a llave centinela `'Unknown'`. | `coalesce(col("pulocationid"), lit(264))` |
| **10** | **Sueldos Via** | 86.9% de los viajes de Via (HV0004) tienen `driver_pay = 0` debido a compensación por turno. | No filtrar ni tratar como error el valor 0 en pago a conductor si la licencia es `HV0004`. | Validar regla condicional de calidad por proveedor. |
| **11** | **Consistencia** | Descuadres contables explicados en más del 95% por recargos no desglosados (+\$0.75, -\$2.50, \(\pm\$1.75\)). | Confiar en los componentes individuales del taxímetro y calcular columna auditable `calculated_total`. | `fare_amount + extra + mta_tax + tip_amount + tolls_amount + ...` |

---

## 5. Justificación Técnica de la Arquitectura de Transformación (AWS Glue)

El volumen consolidado de **4,376 millones de registros distribuidos en 590 archivos Parquet** hace inviable el procesamiento mediante herramientas convencionales en una sola máquina (como pandas o DuckDB mononodo):
- **Cuello de botella de memoria (RAM):** La lectura de años como 2019 o 2025 en un solo formato excede los 200 millones de filas (~30-50 GB en memoria descomprimida), provocando fallos por `OutOfMemory` en estaciones de trabajo locales.
- **Ventaja de AWS Glue (PySpark):**
  - Permite escalar horizontalmente mediante clústeres serverless basados en DPUs (Data Processing Units) tipo `G.1X` o `G.2X`.
  - Capacidad de **procesamiento particionado paralelo**: cada archivo Parquet es procesado por un ejecutor Spark independiente.
  - Implementación nativa de `mergeSchema = true` y manejo resiliente de tipos alternantes sin romperse ante inconsistencias de pandas.
  - Escritura optimizada directamente en S3 con reparticionamiento limpio por año/mes real de servicio.
