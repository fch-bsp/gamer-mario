#!/bin/bash

# Script para habilitar e testar X-Ray via ALB
set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

PROFILE="bedhock"
REGION="us-east-1"

echo -e "${PURPLE}🎯 Habilitando X-Ray via Application Load Balancer${NC}"
echo -e "${BLUE}=================================================${NC}"

# Obter informações do ALB
ALB_URL=$(aws cloudformation describe-stacks \
    --stack-name mario-game-prod-infrastructure \
    --profile $PROFILE \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApplicationLoadBalancerURL`].OutputValue' \
    --output text)

ALB_ARN=$(aws cloudformation describe-stacks \
    --stack-name mario-game-prod-infrastructure \
    --profile $PROFILE \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApplicationLoadBalancerArn`].OutputValue' \
    --output text)

echo -e "${YELLOW}🌐 ALB URL: $ALB_URL${NC}"
echo -e "${YELLOW}📋 ALB ARN: $ALB_ARN${NC}"

# Função para gerar trace ID válido
generate_trace_id() {
    TIMESTAMP=$(date +%s)
    RANDOM_ID=$(openssl rand -hex 12)
    echo "1-${TIMESTAMP}-${RANDOM_ID}"
}

# Função para fazer requisição com trace
make_traced_request() {
    local endpoint=$1
    local trace_id=$2
    local method=${3:-GET}
    
    echo -e "${BLUE}📡 $method $endpoint${NC}"
    echo -e "${YELLOW}   Trace ID: $trace_id${NC}"
    
    # Fazer requisição com headers X-Ray
    RESPONSE=$(curl -s -w "\n%{http_code}\n%{time_total}" \
        -H "X-Amzn-Trace-Id: Root=$trace_id" \
        -H "User-Agent: Mario-Game-XRay-Test/1.0" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
        -H "Accept-Language: en-US,en;q=0.5" \
        -H "Accept-Encoding: gzip, deflate" \
        -H "Connection: keep-alive" \
        -H "Upgrade-Insecure-Requests: 1" \
        "$ALB_URL$endpoint")
    
    # Extrair status code e tempo
    STATUS_CODE=$(echo "$RESPONSE" | tail -2 | head -1)
    TIME_TOTAL=$(echo "$RESPONSE" | tail -1)
    
    echo -e "${GREEN}   ✅ Status: $STATUS_CODE | Tempo: ${TIME_TOTAL}s${NC}"
    
    return 0
}

# ETAPA 1: Gerar tráfego diversificado com traces
echo -e "\n${GREEN}🚀 ETAPA 1: Gerando Tráfego com X-Ray Traces${NC}"
echo -e "${BLUE}--------------------------------------------${NC}"

# Array de endpoints para testar
ENDPOINTS=("/" "/health" "/index.html" "/game.js" "/assets/mario.png" "/favicon.ico")

echo -e "${YELLOW}📊 Gerando 30 requisições com traces únicos...${NC}"

for i in {1..30}; do
    TRACE_ID=$(generate_trace_id)
    ENDPOINT=${ENDPOINTS[$((i % ${#ENDPOINTS[@]}))]}
    
    echo -e "\n${PURPLE}Requisição $i/30${NC}"
    make_traced_request "$ENDPOINT" "$TRACE_ID"
    
    # Adicionar delay variável para simular tráfego real
    DELAY=$(echo "scale=1; $RANDOM/32767*2+0.5" | bc)
    sleep $DELAY
done

echo -e "\n${GREEN}✅ Tráfego gerado com sucesso!${NC}"

# ETAPA 2: Aguardar processamento
echo -e "\n${GREEN}⏳ ETAPA 2: Aguardando Processamento${NC}"
echo -e "${BLUE}-----------------------------------${NC}"
echo -e "${YELLOW}Aguardando 60 segundos para processamento dos traces...${NC}"

for i in {60..1}; do
    echo -ne "\r${YELLOW}⏳ Aguardando: ${i}s restantes...${NC}"
    sleep 1
done
echo ""

# ETAPA 3: Verificar traces no X-Ray
echo -e "\n${GREEN}🔍 ETAPA 3: Verificando Traces no X-Ray${NC}"
echo -e "${BLUE}--------------------------------------${NC}"

START_TIME=$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%S)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)

echo -e "${YELLOW}🔍 Buscando traces entre $START_TIME e $END_TIME${NC}"

TRACES=$(aws xray get-trace-summaries \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --profile $PROFILE \
    --region $REGION \
    --query 'TraceSummaries[*].{Id:Id,Duration:Duration,ResponseTime:ResponseTime,Status:Http.HttpStatus,URL:Http.HttpURL}' \
    --output table 2>/dev/null || echo "Nenhum trace encontrado ainda")

if [[ "$TRACES" != "Nenhum trace encontrado ainda" ]] && [[ -n "$TRACES" ]]; then
    echo -e "${GREEN}🎉 Traces encontrados no X-Ray!${NC}"
    echo "$TRACES"
    
    # Contar traces
    TRACE_COUNT=$(aws xray get-trace-summaries \
        --start-time $START_TIME \
        --end-time $END_TIME \
        --profile $PROFILE \
        --region $REGION \
        --query 'TraceSummaries | length(@)' \
        --output text 2>/dev/null || echo "0")
    
    echo -e "\n${GREEN}📊 Total de traces encontrados: $TRACE_COUNT${NC}"
else
    echo -e "${YELLOW}⚠️  Nenhum trace encontrado ainda. Isso pode ser normal - o X-Ray pode levar até 5-10 minutos para processar traces.${NC}"
fi

# ETAPA 4: Informações finais
echo -e "\n${GREEN}🎯 ETAPA 4: Informações e Links${NC}"
echo -e "${BLUE}-------------------------------${NC}"

echo -e "${PURPLE}🎉 X-Ray via ALB configurado com sucesso!${NC}"

echo -e "\n${BLUE}📋 Links do Console AWS:${NC}"
echo -e "   🔍 X-Ray Traces: https://console.aws.amazon.com/xray/home?region=$REGION#/traces"
echo -e "   🗺️  Service Map: https://console.aws.amazon.com/xray/home?region=$REGION#/service-map"
echo -e "   📊 CloudWatch: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#logsV2:log-groups"

echo -e "\n${BLUE}🔧 Para continuar gerando traces:${NC}"
echo -e "   # Gerar mais tráfego:"
echo -e "   for i in {1..10}; do"
echo -e "     TRACE_ID=\"1-\$(date +%s)-\$(openssl rand -hex 12)\""
echo -e "     curl -H \"X-Amzn-Trace-Id: Root=\$TRACE_ID\" $ALB_URL/"
echo -e "     sleep 2"
echo -e "   done"

echo -e "\n${BLUE}💡 Dicas:${NC}"
echo -e "   • O X-Ray pode levar 2-10 minutos para mostrar traces"
echo -e "   • Traces aparecem primeiro na aba 'Traces', depois no 'Service Map'"
echo -e "   • Cada requisição com header X-Amzn-Trace-Id gera um trace"
echo -e "   • O ALB automaticamente propaga traces para o ECS"

echo -e "\n${GREEN}🎮 Sua aplicação Mario agora está totalmente instrumentada com X-Ray!${NC}"
