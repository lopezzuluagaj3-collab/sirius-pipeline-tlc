# Proyecto Sirius v2 - Infraestructura de ingesta (Extracción)

Módulo de Terraform para la capa de **detección y descarga (extracción)** del pipeline ETL:

```
EventBridge (cron mensual)
  -> Lambda detectora (compara S3 vs fuente TLC)
    -> SQS (un mensaje por periodo faltante)
      -> Lambda descarga (trae el archivo a S3 row)
        -> S3 row
```

Este módulo mantiene acotada la arquitectura exclusivamente a la capa de **extracción**:
- Bucket S3 `row` para almacenar los Parquet ingeridos sin procesar.
- Bucket S3 `logs` para auditoría y logs de acceso S3.
- EventBridge como disparador programado.
- Cola SQS + Dead Letter Queue (DLQ) para control desacoplado y resiliente de periodos.
- Funciones AWS Lambda (detectora y descarga) con roles IAM de mínimo privilegio.

## Requisitos

- Terraform >= 1.7
- Credenciales de AWS con permisos para crear S3, SQS, Lambda, IAM, EventBridge en la cuenta y región configuradas.
- Python 3.12 no es necesario localmente: el código de las Lambdas usa solo librería estándar (`urllib`) + `boto3`, incluido en el runtime de Lambda.

## Despliegue

```bash
terraform init
terraform plan
terraform apply
```

## Decisiones de diseño

- **Lambda detectora**: compara particiones existentes en el bucket S3 `row` (`row/<formato>/anio=YYYY/mes=MM/`) contra la disponibilidad en el CDN oficial de NYC TLC (vía `HEAD` request).
- **SQS como plano de control**: desacopla la detección de la descarga. Cada mensaje contiene metadatos del periodo faltante (`formato`, `anio`, `mes`, `url`).
- **`batch_size = 1`** en el mapeo SQS -> Lambda descarga para aislar fallos por archivo.
- **`visibility_timeout` = 6x timeout de la Lambda**: margen ante reintentos sin visibilidad prematura.
- **IAM de mínimo privilegio**: la Lambda detectora solo lista S3 y encola en SQS; la Lambda de descarga solo consume de SQS y escribe en S3 `row`.
