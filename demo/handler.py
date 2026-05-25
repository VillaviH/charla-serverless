"""
API REST de Tareas — Demo Serverless AWS
========================================
Servicios: Lambda + API Gateway + DynamoDB
Charla: "Despliega como Senior, paga como estudiante"

Endpoints:
  GET    /tasks          → Lista todas las tareas
  GET    /tasks/{id}     → Obtiene una tarea por ID
  POST   /tasks          → Crea una nueva tarea
  PUT    /tasks/{id}     → Actualiza una tarea
  DELETE /tasks/{id}     → Elimina una tarea
"""

import json
import os
import boto3
import uuid
from datetime import datetime

# Cliente de DynamoDB
# TABLE_NAME viene de la variable de entorno que Terraform configura
dynamodb   = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get('TABLE_NAME', 'tasks-demo-tasks')
table      = dynamodb.Table(TABLE_NAME)


# ─────────────────────────────────────────
# Entry point — Lambda lo llama aquí
# ─────────────────────────────────────────
def lambda_handler(event, context):
    method = event.get('httpMethod', '')
    path   = event.get('path', '')

    # API Gateway proxy incluye el stage en el path (ej: /prod/tasks/123)
    # Normalizamos quitando el prefijo del stage
    for prefix in ['/prod', '/dev', '/staging']:
        if path.startswith(prefix):
            path = path[len(prefix):]
            break

    # Routing
    if method == 'GET' and path == '/tasks':
        return get_all_tasks()

    elif method == 'GET' and path.startswith('/tasks/'):
        task_id = event['pathParameters']['id']
        return get_task(task_id)

    elif method == 'POST' and path == '/tasks':
        body = json.loads(event.get('body') or '{}')
        return create_task(body)

    elif method == 'PUT' and path.startswith('/tasks/'):
        task_id = event['pathParameters']['id']
        body    = json.loads(event.get('body') or '{}')
        return update_task(task_id, body)

    elif method == 'DELETE' and path.startswith('/tasks/'):
        task_id = event['pathParameters']['id']
        return delete_task(task_id)

    return build_response(405, {'error': f'Method not allowed: {method} {path}'})


# ─────────────────────────────────────────
# Handlers CRUD
# ─────────────────────────────────────────
def get_all_tasks():
    """Lista todas las tareas de la tabla."""
    result = table.scan()
    tasks  = result.get('Items', [])
    # Ordenar por fecha de creación (más reciente primero)
    tasks.sort(key=lambda x: x.get('created_at', ''), reverse=True)
    return build_response(200, tasks)


def get_task(task_id):
    """Obtiene una tarea por su ID."""
    result = table.get_item(Key={'id': task_id})
    item   = result.get('Item')

    if not item:
        return build_response(404, {'error': f'Task {task_id} not found'})

    return build_response(200, item)


def create_task(body):
    """Crea una nueva tarea."""
    title = body.get('title', '').strip()

    if not title:
        return build_response(400, {'error': 'Field "title" is required'})

    task = {
        'id':         str(uuid.uuid4()),
        'title':      title,
        'completed':  False,
        'created_at': datetime.utcnow().isoformat() + 'Z'
    }

    table.put_item(Item=task)
    return build_response(201, task)


def update_task(task_id, body):
    """Actualiza el título y/o estado de una tarea."""
    # Verificar que existe
    result = table.get_item(Key={'id': task_id})
    if not result.get('Item'):
        return build_response(404, {'error': f'Task {task_id} not found'})

    title     = body.get('title', '').strip()
    completed = body.get('completed')

    if not title:
        return build_response(400, {'error': 'Field "title" is required'})
    if completed is None:
        return build_response(400, {'error': 'Field "completed" is required'})

    table.update_item(
        Key={'id': task_id},
        UpdateExpression='SET title = :t, completed = :c, updated_at = :u',
        ExpressionAttributeValues={
            ':t': title,
            ':c': bool(completed),
            ':u': datetime.utcnow().isoformat() + 'Z'
        }
    )

    return build_response(200, {'message': 'Task updated', 'id': task_id})


def delete_task(task_id):
    """Elimina una tarea por su ID."""
    # Verificar que existe
    result = table.get_item(Key={'id': task_id})
    if not result.get('Item'):
        return build_response(404, {'error': f'Task {task_id} not found'})

    table.delete_item(Key={'id': task_id})
    return build_response(200, {'message': 'Task deleted', 'id': task_id})


# ─────────────────────────────────────────
# Helper — construye la respuesta HTTP
# ─────────────────────────────────────────
def build_response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',   # Permite llamadas desde el browser
        },
        'body': json.dumps(body, default=str)
    }
