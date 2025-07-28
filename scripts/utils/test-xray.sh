#!/bin/bash

# Script para testar X-Ray tracing
set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROFILE="bedhock"
REGION="us-east-1"

echo -e "${BLUE}🔍 Testando X-Ray Tracing${NC}"

# Obter URL do ALB
ALB_URL=$(aws cloudformation describe-stacks \
    --stack-name mario-game-prod-infrastructure \
    --profile $PROFILE \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApplicationLoadBalancerURL`].OutputValue' \
    --output text)

echo -e "${YELLOW}🌐 URL da aplicação: $ALB_URL${NC}"

# Gerar tráfego com trace headers
echo -e "${BLUE}📊 Gerando tráfego com trace headers...${NC}"

for i in {1..10}; do
    TRACE_ID="1-$(date +%s)-$(openssl rand -hex 12)"
    echo -e "${YELLOW}Requisição $i - Trace ID: $TRACE_ID${NC}"
    
    curl -s -H "X-Amzn-Trace-Id: Root=$TRACE_ID" \
         -H "User-Agent: XRayTest/1.0" \
         "$ALB_URL/" > /dev/null
    
    curl -s -H "X-Amzn-Trace-Id: Root=$TRACE_ID" \
         -H "User-Agent: XRayTest/1.0" \
         "$ALB_URL/health" > /dev/null
    
    sleep 1
done

echo -e "${GREEN}✅ Tráfego gerado com sucesso!${NC}"

# Aguardar um pouco para os traces serem processados
echo -e "${YELLOW}⏳ Aguardando processamento dos traces (30s)...${NC}"
sleep 30

# Verificar traces
echo -e "${BLUE}🔍 Verificando traces no X-Ray...${NC}"
START_TIME=$(date -d '5 minutes ago' -u +%Y-%m-%dT%H:%M:%S)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)

aws xray get-trace-summaries \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --profile $PROFILE \
    --region $REGION \
    --query 'TraceSummaries[*].{Id:Id,Duration:Duration,ResponseTime:ResponseTime,Http:Http.HttpStatus}' \
    --output table

echo -e "${GREEN}🎯 Teste concluído!${NC}"
echo -e "${BLUE}📋 Para ver no console AWS:${NC}"
echo -e "   https://console.aws.amazon.com/xray/home?region=$REGION#/traces"
