# Módulo: lambda_method
# Crea UN método HTTP en API Gateway integrado con Lambda.
# El OPTIONS se maneja en modules/cors_options (llamar una vez por recurso).

variable "rest_api_id" { type = string }
variable "resource_id" { type = string }
variable "http_method" { type = string }
variable "lambda_arn"  { type = string }

resource "aws_api_gateway_method" "this" {
  rest_api_id   = var.rest_api_id
  resource_id   = var.resource_id
  http_method   = var.http_method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "this" {
  rest_api_id             = var.rest_api_id
  resource_id             = var.resource_id
  http_method             = aws_api_gateway_method.this.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_arn
}
