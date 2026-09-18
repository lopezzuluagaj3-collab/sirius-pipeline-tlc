terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  backend "s3" {
    bucket       = "sirius-tfstate-603437461408"
    key          = "sirius-pipeline/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "s3" {
  source = "./models/s3"

  project_name = var.project_name
}

module "sqs" {
  source = "./models/sqs"

  project_name            = var.project_name
  lambda_descarga_timeout = var.lambda_descarga_timeout
  sqs_max_receive_count   = var.sqs_max_receive_count
}

module "iam" {
  source = "./models/iam"

  project_name                 = var.project_name
  aws_region                   = var.aws_region
  row_bucket_arn               = module.s3.row_bucket_arn
  periodos_faltantes_queue_arn = module.sqs.periodos_faltantes_queue_arn
}

module "lambda" {
  source = "./models/lambda"

  project_name                 = var.project_name
  row_bucket_name              = module.s3.row_bucket_name
  periodos_faltantes_queue_url = module.sqs.periodos_faltantes_queue_url
  periodos_faltantes_queue_arn = module.sqs.periodos_faltantes_queue_arn
  detectora_role_arn           = module.iam.detectora_role_arn
  descarga_role_arn            = module.iam.descarga_role_arn
  formatos                     = var.formatos
  fecha_inicio                 = var.fecha_inicio
  fecha_inicio_por_formato     = var.fecha_inicio_por_formato
  tlc_base_url                 = var.tlc_base_url
  lambda_detectora_timeout     = var.lambda_detectora_timeout
  lambda_descarga_timeout      = var.lambda_descarga_timeout
  lambda_descarga_memory       = var.lambda_descarga_memory
}

module "eventbridge" {
  source = "./models/eventbridge"

  project_name         = var.project_name
  schedule_expression  = var.schedule_expression
  lambda_function_name = module.lambda.lambda_detectora_name
  lambda_function_arn  = module.lambda.lambda_detectora_arn
}
