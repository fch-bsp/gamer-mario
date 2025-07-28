#!/bin/bash

# Script para gerar traces sintéticos no X-Ray
set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROFILE="bedhock"
REGION="us-east-1"
SERVICE_NAME="mario-game-prod"

echo -e "${BLUE}🎯 Gerando Traces Sintéticos para X-Ray${NC}"

# Obter URL do ALB
ALB_URL=$(aws cloudformation describe-stacks \
    --stack-name mario-game-prod-infrastructure \
    --profile $PROFILE \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApplicationLoadBalancerURL`].OutputValue' \
    --output text)

echo -e "${YELLOW}🌐 URL da aplicação: $ALB_URL${NC}"

# Função para gerar trace ID
generate_trace_id() {
    TIMESTAMP=$(date +%s)
    RANDOM_ID=$(openssl rand -hex 12)
    echo "1-${TIMESTAMP}-${RANDOM_ID}"
}

# Função para gerar segment ID
generate_segment_id() {
    openssl rand -hex 8
}

# Função para criar trace segment JSON
create_trace_segment() {
    local trace_id=$1
    local segment_id=$2
    local start_time=$3
    local end_time=$4
    local http_status=$5
    local http_method=$6
    local http_url=$7
    
    cat <<EOF
{
    "trace_id": "${trace_id}",
    "id": "${segment_id}",
    "name": "${SERVICE_NAME}",
    "start_time": ${start_time},
    "end_time": ${end_time},
    "http": {
        "request": {
            "method": "${http_method}",
            "url": "${http_url}",
            "user_agent": "Mario-Game-Synthetic-Trace/1.0"
        },
        "response": {
            "status": ${http_status}
        }
    },
    "service": {
        "name": "${SERVICE_NAME}",
        "version": "1.0"
    },
    "aws": {
        "ecs": {
            "container_name": "mario-game-container",
            "cluster_name": "mario-game-prod-cluster"
        }
    },
    "annotations": {
        "environment": "prod",
        "game": "super-mario-bros"
    },
    "metadata": {
        "mario_game": {
            "level": "1-1",
            "score": 1000,
            "lives": 3
        }
    }
}
EOF
}

# Gerar múltiplos traces
echo -e "${BLUE}📊 Gerando 20 traces sintéticos...${NC}"

for i in {1..20}; do
    TRACE_ID=$(generate_trace_id)
    SEGMENT_ID=$(generate_segment_id)
    
    # Simular diferentes tempos de resposta
    START_TIME=$(date +%s.%3N)
    RESPONSE_TIME=$(echo "scale=3; $RANDOM/32767*0.5+0.1" | bc)
    END_TIME=$(echo "$START_TIME + $RESPONSE_TIME" | bc)
    
    # Simular diferentes endpoints e status codes
    case $((i % 4)) in
        0) ENDPOINT="/"; STATUS=200 ;;
        1) ENDPOINT="/health"; STATUS=200 ;;
        2) ENDPOINT="/game.js"; STATUS=200 ;;
        3) ENDPOINT="/assets/mario.png"; STATUS=200 ;;
    esac
    
    # Ocasionalmente simular erro
    if [ $((i % 10)) -eq 0 ]; then
        STATUS=500
    fi
    
    SEGMENT_JSON=$(create_trace_segment "$TRACE_ID" "$SEGMENT_ID" "$START_TIME" "$END_TIME" "$STATUS" "GET" "$ENDPOINT")
    
    echo -e "${YELLOW}Trace $i: $TRACE_ID - $ENDPOINT (${STATUS})${NC}"
    
    # Enviar trace via AWS CLI (método mais confiável)
    echo "$SEGMENT_JSON" | aws xray put-trace-segments \
        --trace-segment-documents file:///dev/stdin \
        --profile $PROFILE \
        --region $REGION > /dev/null
    
    # Fazer requisição real também
    curl -s -H "X-Amzn-Trace-Id: Root=$TRACE_ID" \
         -H "User-Agent: Mario-Game-Synthetic-Trace/1.0" \
         "$ALB_URL$ENDPOINT" > /dev/null || true
    
    sleep 0.5
done

echo -e "${GREEN}✅ 20 traces sintéticos gerados com sucesso!${NC}"

# Aguardar processamento
echo -e "${YELLOW}⏳ Aguardando processamento dos traces (30s)...${NC}"
sleep 30

# Verificar traces
echo -e "${BLUE}🔍 Verificando traces no X-Ray...${NC}"
START_TIME=$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%S)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)

TRACES=$(aws xray get-trace-summaries \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --profile $PROFILE \
    --region $REGION \
    --query 'TraceSummaries[*].{Id:Id,Duration:Duration,ResponseTime:ResponseTime,Status:Http.HttpStatus}' \
    --output table)

if [ -n "$TRACES" ] && [ "$TRACES" != "None" ]; then
    echo -e "${GREEN}🎉 Traces encontrados no X-Ray!${NC}"
    echo "$TRACES"
else
    echo -e "${RED}❌ Nenhum trace encontrado ainda. Aguarde mais alguns minutos.${NC}"
fi

echo -e "\n${GREEN}🎯 Geração de traces concluída!${NC}"
echo -e "${BLUE}📋 Para ver no console AWS:${NC}"
echo -e "   https://console.aws.amazon.com/xray/home?region=$REGION#/traces"
echo -e "\n${BLUE}📋 Para ver o Service Map:${NC}"
echo -e "   https://console.aws.amazon.com/xray/home?region=$REGION#/service-map"
