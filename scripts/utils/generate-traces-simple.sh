#!/bin/bash

# Script simplificado para gerar traces no X-Ray
set -e

PROFILE="bedhock"
REGION="us-east-1"
SERVICE_NAME="mario-game-prod"

echo "🎯 Gerando Traces para X-Ray"

# Função para gerar trace ID
generate_trace_id() {
    TIMESTAMP=$(date +%s)
    RANDOM_ID=$(openssl rand -hex 12)
    echo "1-${TIMESTAMP}-${RANDOM_ID}"
}

# Gerar 5 traces simples
for i in {1..5}; do
    TRACE_ID=$(generate_trace_id)
    SEGMENT_ID=$(openssl rand -hex 8)
    
    START_TIME=$(date +%s.%3N)
    END_TIME=$(echo "$START_TIME + 0.1" | bc)
    
    # Criar segment JSON simples
    SEGMENT_JSON=$(cat <<EOF
{
    "trace_id": "${TRACE_ID}",
    "id": "${SEGMENT_ID}",
    "name": "${SERVICE_NAME}",
    "start_time": ${START_TIME},
    "end_time": ${END_TIME},
    "http": {
        "request": {
            "method": "GET",
            "url": "/"
        },
        "response": {
            "status": 200
        }
    }
}
EOF
)
    
    echo "Enviando trace $i: $TRACE_ID"
    
    # Criar arquivo temporário
    TEMP_FILE=$(mktemp)
    echo "$SEGMENT_JSON" > "$TEMP_FILE"
    
    # Enviar trace
    aws xray put-trace-segments \
        --trace-segment-documents "file://$TEMP_FILE" \
        --profile $PROFILE \
        --region $REGION
    
    # Limpar arquivo temporário
    rm "$TEMP_FILE"
    
    sleep 2
done

echo "✅ 5 traces enviados com sucesso!"

# Aguardar e verificar
sleep 30
echo "🔍 Verificando traces..."

START_TIME=$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%S)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)

aws xray get-trace-summaries \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --profile $PROFILE \
    --region $REGION \
    --query 'TraceSummaries[*].{Id:Id,Duration:Duration}' \
    --output table

echo "📋 Console AWS X-Ray:"
echo "https://console.aws.amazon.com/xray/home?region=$REGION#/traces"
