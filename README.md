# Despliega como Senior, paga como estudiante
### Serverless en AWS: Lambda + API Gateway + DynamoDB + Terraform

> Código de la charla presentada en la Universidad de Cuenca · 2026  
> AWS User Group Ecuador

---

## ¿Qué vas a construir?

Una API REST completa de tareas (To-Do) desplegada en AWS usando servicios 100% serverless:

```
Browser → API Gateway → Lambda (Python) → DynamoDB
              ↑
         S3 (frontend estático)
```

**Costo total: $0** — todo entra en el Free Tier de AWS.

---

## Prerrequisitos

| Herramienta | Versión mínima | Instalación |
|-------------|---------------|-------------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.0 | `brew install terraform` |
| [AWS CLI](https://aws.amazon.com/cli/) | >= 2.0 | `brew install awscli` |
| Cuenta AWS | Free Tier | [aws.amazon.com/free](https://aws.amazon.com/free) |
| Python | >= 3.10 | Solo para leer el código, no para ejecutar |

---

## Configurar credenciales AWS

```bash
aws configure
# AWS Access Key ID:     TU_ACCESS_KEY
# AWS Secret Access Key: TU_SECRET_KEY
# Default region name:   us-east-1
# Default output format: json

# Verificar que funciona
aws sts get-caller-identity
```

> **¿Cómo obtengo las credenciales?**  
> En la consola AWS → IAM → Users → Tu usuario → Security credentials → Create access key

---

## Desplegar en 3 comandos

```bash
# 1. Clonar el repo
git clone https://github.com/TU_USUARIO/charla-serverless.git
cd charla-serverless/demo/terraform

# 2. Inicializar Terraform (descarga providers)
terraform init

# 3. Desplegar toda la infraestructura
terraform apply
# → Escribe "yes" cuando te lo pida
# → Espera ~90 segundos
```

Al terminar, Terraform imprime las URLs:

```
api_url      = "https://abc123.execute-api.us-east-1.amazonaws.com/prod/tasks"
frontend_url = "http://tasks-demo-frontend-xxxx.s3-website-us-east-1.amazonaws.com"
```

Abre `frontend_url` en el browser y ya tienes la app funcionando.

---

## Probar la API con curl

```bash
# Guardar la URL base
export BASE=$(terraform output -raw api_url | sed 's|/tasks||')

# Crear una tarea
curl -s -X POST "$BASE/tasks" \
  -H "Content-Type: application/json" \
  -d '{"title": "Mi primera tarea serverless 🚀"}' | python3 -m json.tool

# Listar tareas
curl -s "$BASE/tasks" | python3 -m json.tool

# O usar el script automático
BASE_URL=$BASE ../test-api.sh
```

---

## Estructura del proyecto

```
charla-serverless/
├── slides.html                  # Presentación de la charla (abrir en browser)
├── GUIA-DEMO.md                 # Guía paso a paso del demo en vivo
└── demo/
    ├── handler.py               # Código de la Lambda — toda la lógica de la API
    ├── test-api.sh              # Script para probar todos los endpoints
    ├── iam-policy.json          # Referencia de permisos IAM
    ├── frontend/
    │   └── index.html           # Frontend estático (Terraform lo sube a S3)
    └── terraform/
        ├── main.tf              # Recursos: DynamoDB, Lambda, API Gateway, S3
        ├── variables.tf         # Parámetros configurables
        ├── outputs.tf           # URLs que imprime Terraform al terminar
        └── modules/
            ├── lambda_method/   # Módulo: conecta un método HTTP con Lambda
            └── cors_options/    # Módulo: maneja el preflight CORS
```

---

## Recursos que crea Terraform

| Recurso | Nombre | Para qué |
|---------|--------|----------|
| `aws_dynamodb_table` | `tasks-demo-tasks` | Base de datos NoSQL |
| `aws_lambda_function` | `tasks-demo-api` | Lógica de la API |
| `aws_api_gateway_rest_api` | `tasks-demo-api` | Endpoints HTTP públicos |
| `aws_s3_bucket` | `tasks-demo-frontend-xxxx` | Frontend estático |
| `aws_iam_role` | `tasks-demo-lambda-role` | Permisos de Lambda |

---

## Limpiar todo al terminar

```bash
terraform destroy
# → Escribe "yes"
# → En ~30 segundos borra todo
```

Esto elimina **todos** los recursos creados. Costo final: $0.

---

## Personalizar el proyecto

Edita `demo/terraform/variables.tf` para cambiar el nombre del proyecto o la región:

```hcl
variable "project_name" {
  default = "mi-app"        # cambia esto
}

variable "aws_region" {
  default = "us-east-1"     # o "sa-east-1" para São Paulo (más cerca)
}
```

---

## Solución de problemas comunes

| Error | Causa | Solución |
|-------|-------|----------|
| `No valid credential sources found` | AWS CLI no configurado | `aws configure` |
| `EntityAlreadyExists: Role ... already exists` | Rol huérfano de deploy anterior | `terraform import aws_iam_role.lambda_role tasks-demo-lambda-role` |
| `502 Bad Gateway` | Error en el código Python | `terraform output cloudwatch_logs_url` para ver los logs |
| `AccessDeniedException` en DynamoDB | Permisos IAM incorrectos | Verificar `aws_iam_role_policy.lambda_dynamodb` en main.tf |

---

## Recursos para seguir aprendiendo

- [AWS Free Tier](https://aws.amazon.com/free) — crea tu cuenta gratis
- [AWS Skill Builder](https://skillbuilder.aws) — cursos oficiales gratuitos
- [Documentación de Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [The Burning Monk](https://theburningmonk.com) — el mejor blog de Lambda

---

## Autor

**Hernán Villavicencio**  
AWS User Group Ecuador  
[linkedin.com/in/TU_PERFIL](https://linkedin.com/in/TU_PERFIL)
