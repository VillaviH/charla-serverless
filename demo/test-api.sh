#!/bin/bash
# ─────────────────────────────────────────────────────────────
# test-api.sh — Prueba rápida de la API de Tareas
# Uso: BASE_URL=https://TU_ID.execute-api.us-east-1.amazonaws.com/prod ./test-api.sh
# ─────────────────────────────────────────────────────────────

BASE="${BASE_URL:-https://TU_ID.execute-api.us-east-1.amazonaws.com/prod}"

echo ""
echo "🚀 Probando API de Tareas Serverless"
echo "   URL: $BASE"
echo "────────────────────────────────────────"

# 1. Crear tarea
echo ""
echo "📝 [POST] Crear tarea..."
RESPONSE=$(curl -s -X POST "$BASE/tasks" \
  -H "Content-Type: application/json" \
  -d '{"title": "Aprender serverless en AWS"}')
echo "$RESPONSE" | python3 -m json.tool
TASK_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "   → ID creado: $TASK_ID"

# 2. Listar tareas
echo ""
echo "📋 [GET] Listar todas las tareas..."
curl -s "$BASE/tasks" | python3 -m json.tool

# 3. Obtener tarea por ID
echo ""
echo "🔍 [GET] Obtener tarea por ID..."
curl -s "$BASE/tasks/$TASK_ID" | python3 -m json.tool

# 4. Actualizar tarea
echo ""
echo "✏️  [PUT] Marcar tarea como completada..."
curl -s -X PUT "$BASE/tasks/$TASK_ID" \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"Aprender serverless en AWS\", \"completed\": true}" \
  | python3 -m json.tool

# 5. Verificar actualización
echo ""
echo "✅ [GET] Verificar que se actualizó..."
curl -s "$BASE/tasks/$TASK_ID" | python3 -m json.tool

# 6. Eliminar tarea
echo ""
echo "🗑️  [DELETE] Eliminar tarea..."
curl -s -X DELETE "$BASE/tasks/$TASK_ID" | python3 -m json.tool

# 7. Verificar que fue eliminada
echo ""
echo "❓ [GET] Verificar que fue eliminada (debe dar 404)..."
curl -s "$BASE/tasks/$TASK_ID" | python3 -m json.tool

echo ""
echo "────────────────────────────────────────"
echo "✅ Demo completado"
