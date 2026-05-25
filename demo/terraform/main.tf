terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────
# DynamoDB — Tabla de tareas
# ─────────────────────────────────────────
resource "aws_dynamodb_table" "tasks" {
  name         = "${var.project_name}-tasks"
  billing_mode = "PAY_PER_REQUEST"   # Serverless: pagas por operación, no por capacidad
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Project = var.project_name
    Env     = var.environment
  }
}

# ─────────────────────────────────────────
# IAM — Rol para Lambda
# ─────────────────────────────────────────
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Project = var.project_name
  }
}

# Permisos básicos de Lambda (logs en CloudWatch)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Permisos para leer/escribir en DynamoDB
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.project_name}-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan",
        "dynamodb:Query"
      ]
      Resource = aws_dynamodb_table.tasks.arn
    }]
  })
}

# ─────────────────────────────────────────
# Lambda — Empaquetar y desplegar el código
# ─────────────────────────────────────────

# Crea el ZIP del handler automáticamente
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../handler.py"
  output_path = "${path.module}/function.zip"
}

resource "aws_lambda_function" "tasks_api" {
  function_name    = "${var.project_name}-api"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime       = "python3.12"
  architectures = ["arm64"]          # Graviton2: 20% más barato y más rápido
  handler       = "handler.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  timeout       = 10
  memory_size   = 128

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.tasks.name
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    Project = var.project_name
    Env     = var.environment
  }
}

# ─────────────────────────────────────────
# API Gateway — REST API
# ─────────────────────────────────────────
resource "aws_api_gateway_rest_api" "tasks_api" {
  name        = "${var.project_name}-api"
  description = "API REST de Tareas — Demo Serverless"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Project = var.project_name
  }
}

# Recurso: /tasks
resource "aws_api_gateway_resource" "tasks" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  parent_id   = aws_api_gateway_rest_api.tasks_api.root_resource_id
  path_part   = "tasks"
}

# Recurso: /tasks/{id}
resource "aws_api_gateway_resource" "task_id" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  parent_id   = aws_api_gateway_resource.tasks.id
  path_part   = "{id}"
}

# ── Métodos en /tasks ──────────────────────
module "tasks_get" {
  source      = "./modules/lambda_method"
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = "GET"
  lambda_arn  = aws_lambda_function.tasks_api.invoke_arn
}

module "tasks_post" {
  source      = "./modules/lambda_method"
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = "POST"
  lambda_arn  = aws_lambda_function.tasks_api.invoke_arn
}

module "tasks_cors" {
  source      = "./modules/cors_options"
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks.id
}

# ── Métodos en /tasks/{id} ─────────────────
module "task_get" {
  source      = "./modules/lambda_method"
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.task_id.id
  http_method = "GET"
  lambda_arn  = aws_lambda_function.tasks_api.invoke_arn
}

module "task_put" {
  source      = "./modules/lambda_method"
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.task_id.id
  http_method = "PUT"
  lambda_arn  = aws_lambda_function.tasks_api.invoke_arn
}

module "task_delete" {
  source      = "./modules/lambda_method"
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.task_id.id
  http_method = "DELETE"
  lambda_arn  = aws_lambda_function.tasks_api.invoke_arn
}

module "task_id_cors" {
  source      = "./modules/cors_options"
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.task_id.id
}

# ── Deployment ─────────────────────────────
resource "aws_api_gateway_deployment" "prod" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id

  # Forzar re-deploy cuando cambian los métodos
  triggers = {
    redeployment = sha1(jsonencode([
      module.tasks_get,
      module.tasks_post,
      module.tasks_cors,
      module.task_get,
      module.task_put,
      module.task_delete,
      module.task_id_cors,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.prod.id
  rest_api_id   = aws_api_gateway_rest_api.tasks_api.id
  stage_name    = var.environment
}

# ── Permiso para que API Gateway invoque Lambda ──
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tasks_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.tasks_api.execution_arn}/*/*"
}

# ─────────────────────────────────────────
# S3 — Frontend estático
# ─────────────────────────────────────────

resource "aws_s3_bucket" "frontend" {
  bucket        = "${var.project_name}-frontend-${random_id.suffix.hex}"
  force_destroy = true   # Permite destruir aunque tenga archivos

  tags = {
    Project = var.project_name
    Env     = var.environment
  }
}

# ID aleatorio para que el nombre del bucket sea único globalmente
resource "random_id" "suffix" {
  byte_length = 4
}

# Habilitar static website hosting
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document { suffix = "index.html" }
  error_document { key    = "index.html" }
}

# Deshabilitar el bloqueo de acceso público (necesario para sitio público)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy: acceso público de lectura
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  depends_on = [aws_s3_bucket_public_access_block.frontend]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
    }]
  })
}

# Inyectar la URL de la API en el HTML y subirlo al bucket
resource "aws_s3_object" "index_html" {
  bucket = aws_s3_bucket.frontend.id
  key    = "index.html"

  # Reemplaza el placeholder con la URL real de API Gateway
  content = replace(
    file("${path.module}/../frontend/index.html"),
    "API_GATEWAY_URL_PLACEHOLDER",
    "https://${aws_api_gateway_rest_api.tasks_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
  )

  content_type = "text/html"

  # Re-sube si cambia el HTML o la URL de la API
  etag = md5(replace(
    file("${path.module}/../frontend/index.html"),
    "API_GATEWAY_URL_PLACEHOLDER",
    "https://${aws_api_gateway_rest_api.tasks_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
  ))
}
