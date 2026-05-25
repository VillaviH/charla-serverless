variable "aws_region" {
  description = "Región de AWS donde se despliega la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto (se usa como prefijo en todos los recursos)"
  type        = string
  default     = "tasks-demo"
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "prod"
}
