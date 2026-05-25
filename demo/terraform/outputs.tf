output "api_url" {
  description = "URL base de la API — úsala para probar con curl"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/tasks"
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda"
  value       = aws_lambda_function.tasks_api.function_name
}

output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB"
  value       = aws_dynamodb_table.tasks.name
}

output "cloudwatch_logs_url" {
  description = "URL directa a los logs de Lambda en CloudWatch"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/%2Faws%2Flambda%2F${aws_lambda_function.tasks_api.function_name}"
}

output "frontend_url" {
  description = "URL del frontend en S3 — ábrela en el browser"
  value       = "http://${aws_s3_bucket_website_configuration.frontend.website_endpoint}"
}
