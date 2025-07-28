#!/bin/bash

# Mario Game - Gerenciamento X-Ray
# Script para gerenciar traces, monitoramento e configurações X-Ray

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configurações
ENVIRONMENT=${1:-prod}
ACTION=${2:-status}
REGION="us-east-1"
PROFILE="bedhock"

echo -e "${PURPLE}🔍 Mario Game - Gerenciamento X-Ray${NC}"
echo -e "${BLUE}===================================${NC}"
echo -e "${YELLOW}Ambiente: $ENVIRONMENT${NC}"
echo -e "${YELLOW}Ação: $ACTION${NC}"
echo -e "${YELLOW}Região: $REGION${NC}"
echo -e "${BLUE}===================================${NC}"

# Função para mostrar ajuda
show_help() {
    echo -e "${BLUE}📋 Uso: ./scripts/manage-xray.sh [ambiente] [ação]${NC}"
    echo ""
    echo -e "${YELLOW}Ações disponíveis:${NC}"
    echo -e "   ${GREEN}status${NC}     - Verificar status do X-Ray"
    echo -e "   ${GREEN}traces${NC}     - Listar traces recentes"
    echo -e "   ${GREEN}generate${NC}   - Gerar traces de teste"
    echo -e "   ${GREEN}monitor${NC}    - Monitorar traces em tempo real"
    echo -e "   ${GREEN}cleanup${NC}    - Limpar configurações X-Ray"
    echo -e "   ${GREEN}console${NC}    - Mostrar links do console AWS"
    echo ""
    echo -e "${YELLOW}Exemplos:${NC}"
    echo -e "   ./scripts/manage-xray.sh prod status"
    echo -e "   ./scripts/manage-xray.sh prod generate"
    echo -e "   ./scripts/manage-xray.sh prod monitor"
}

# Função para obter URL do ALB
get_alb_url() {
    aws cloudformation describe-stacks \
        --stack-name mario-game-$ENVIRONMENT-infrastructure \
        --profile $PROFILE \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`ApplicationLoadBalancerURL`].OutputValue' \
        --output text 2>/dev/null || echo ""
}

# Função para verificar status
check_status() {
    echo -e "\n${GREEN}📊 Status do X-Ray${NC}"
    echo -e "${BLUE}------------------${NC}"
    
    # Verificar ECS Service
    echo -e "${YELLOW}🔍 Verificando ECS Service...${NC}"
    ECS_STATUS=$(aws ecs describe-services \
        --cluster mario-game-$ENVIRONMENT-cluster \
        --services mario-game-$ENVIRONMENT-service \
        --profile $PROFILE \
        --region $REGION \
        --query 'services[0].status' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$ECS_STATUS" = "ACTIVE" ]; then
        RUNNING_COUNT=$(aws ecs describe-services \
            --cluster mario-game-$ENVIRONMENT-cluster \
            --services mario-game-$ENVIRONMENT-service \
            --profile $PROFILE \
            --region $REGION \
            --query 'services[0].runningCount' \
            --output text)
        echo -e "${GREEN}✅ ECS Service: $ECS_STATUS ($RUNNING_COUNT containers)${NC}"
        
        # Verificar containers
        TASK_ARN=$(aws ecs list-tasks \
            --cluster mario-game-$ENVIRONMENT-cluster \
            --service-name mario-game-$ENVIRONMENT-service \
            --profile $PROFILE \
            --region $REGION \
            --query 'taskArns[0]' \
            --output text 2>/dev/null || echo "")
        
        if [ ! -z "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
            echo -e "${YELLOW}🔍 Status dos containers:${NC}"
            aws ecs describe-tasks \
                --cluster mario-game-$ENVIRONMENT-cluster \
                --tasks $TASK_ARN \
                --profile $PROFILE \
                --region $REGION \
                --query 'tasks[0].containers[*].{Name:name,Status:lastStatus,Health:healthStatus}' \
                --output table
        fi
    else
        echo -e "${RED}❌ ECS Service: $ECS_STATUS${NC}"
    fi
    
    # Verificar conectividade X-Ray
    echo -e "${YELLOW}🔍 Verificando conectividade X-Ray...${NC}"
    XRAY_RULES=$(aws xray get-sampling-rules \
        --profile $PROFILE \
        --region $REGION \
        --query 'SamplingRuleRecords | length(@)' \
        --output text 2>/dev/null || echo "ERROR")
    
    if [ "$XRAY_RULES" != "ERROR" ]; then
        echo -e "${GREEN}✅ X-Ray conectividade: OK ($XRAY_RULES sampling rules)${NC}"
    else
        echo -e "${RED}❌ Problema de conectividade com X-Ray${NC}"
    fi
    
    # Verificar traces recentes
    echo -e "${YELLOW}🔍 Verificando traces recentes...${NC}"
    START_TIME=$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%S)
    END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
    
    TRACE_COUNT=$(aws xray get-trace-summaries \
        --start-time $START_TIME \
        --end-time $END_TIME \
        --profile $PROFILE \
        --region $REGION \
        --query 'TraceSummaries | length(@)' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$TRACE_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✅ Traces encontrados: $TRACE_COUNT (última hora)${NC}"
    else
        echo -e "${YELLOW}⚠️  Nenhum trace encontrado na última hora${NC}"
    fi
}

# Função para listar traces
list_traces() {
    echo -e "\n${GREEN}📋 Traces Recentes${NC}"
    echo -e "${BLUE}------------------${NC}"
    
    START_TIME=$(date -d '6 hours ago' -u +%Y-%m-%dT%H:%M:%S)
    END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
    
    echo -e "${YELLOW}🔍 Buscando traces entre $START_TIME e $END_TIME${NC}"
    
    TRACES=$(aws xray get-trace-summaries \
        --start-time $START_TIME \
        --end-time $END_TIME \
        --profile $PROFILE \
        --region $REGION \
        --query 'TraceSummaries[*].{Id:Id,Duration:Duration,Status:Http.HttpStatus,Method:Http.HttpMethod,URL:Http.HttpURL}' \
        --output table 2>/dev/null || echo "")
    
    if [ ! -z "$TRACES" ]; then
        echo "$TRACES"
    else
        echo -e "${YELLOW}⚠️  Nenhum trace encontrado nas últimas 6 horas${NC}"
    fi
}

# Função para gerar traces
generate_traces() {
    echo -e "\n${GREEN}🧪 Gerando Traces de Teste${NC}"
    echo -e "${BLUE}---------------------------${NC}"
    
    ALB_URL=$(get_alb_url)
    
    if [ -z "$ALB_URL" ]; then
        echo -e "${RED}❌ Não foi possível obter URL do ALB${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}🌐 URL: $ALB_URL${NC}"
    echo -e "${YELLOW}📡 Gerando 10 traces de teste...${NC}"
    
    for i in {1..10}; do
        TRACE_ID="1-$(date +%s)-$(openssl rand -hex 12)"
        echo -e "${BLUE}   Trace $i: $TRACE_ID${NC}"
        
        # Fazer requisições com trace ID
        curl -s -H "X-Amzn-Trace-Id: Root=$TRACE_ID" \
             -H "User-Agent: Mario-XRay-Manager/1.0" \
             "$ALB_URL/" > /dev/null || true
        
        curl -s -H "X-Amzn-Trace-Id: Root=$TRACE_ID" \
             -H "User-Agent: Mario-XRay-Manager/1.0" \
             "$ALB_URL/health" > /dev/null || true
        
        sleep 1
    done
    
    echo -e "${GREEN}✅ 10 traces gerados com sucesso!${NC}"
    echo -e "${YELLOW}💡 Aguarde 2-5 minutos para ver os traces no console${NC}"
}

# Função para monitorar traces
monitor_traces() {
    echo -e "\n${GREEN}📊 Monitoramento de Traces${NC}"
    echo -e "${BLUE}---------------------------${NC}"
    
    echo -e "${YELLOW}Monitorando por 5 minutos (verificando a cada 30s)...${NC}"
    
    for i in {1..10}; do
        TIMESTAMP=$(date '+%H:%M:%S')
        START_TIME=$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%S)
        END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
        
        TRACE_COUNT=$(aws xray get-trace-summaries \
            --start-time $START_TIME \
            --end-time $END_TIME \
            --profile $PROFILE \
            --region $REGION \
            --query 'TraceSummaries | length(@)' \
            --output text 2>/dev/null || echo "0")
        
        if [ "$TRACE_COUNT" -gt 0 ]; then
            echo -e "${GREEN}✅ [$TIMESTAMP] $TRACE_COUNT traces encontrados${NC}"
        else
            echo -e "${YELLOW}⏳ [$TIMESTAMP] Aguardando traces... ($i/10)${NC}"
        fi
        
        if [ $i -lt 10 ]; then
            sleep 30
        fi
    done
}

# Função para mostrar links do console
show_console() {
    echo -e "\n${GREEN}🌐 Links do Console AWS${NC}"
    echo -e "${BLUE}----------------------${NC}"
    
    echo -e "${PURPLE}🔍 X-Ray:${NC}"
    echo -e "   Traces: https://console.aws.amazon.com/xray/home?region=$REGION#/traces"
    echo -e "   Service Map: https://console.aws.amazon.com/xray/home?region=$REGION#/service-map"
    echo -e "   Analytics: https://console.aws.amazon.com/xray/home?region=$REGION#/analytics"
    
    echo -e "\n${PURPLE}📊 CloudWatch:${NC}"
    echo -e "   Logs: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#logsV2:log-groups/log-group/\$252Fecs\$252Fmario-game-$ENVIRONMENT"
    echo -e "   Metrics: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#metricsV2:"
    
    echo -e "\n${PURPLE}🚀 ECS:${NC}"
    echo -e "   Cluster: https://console.aws.amazon.com/ecs/home?region=$REGION#/clusters/mario-game-$ENVIRONMENT-cluster"
    echo -e "   Service: https://console.aws.amazon.com/ecs/home?region=$REGION#/clusters/mario-game-$ENVIRONMENT-cluster/services/mario-game-$ENVIRONMENT-service"
    
    ALB_URL=$(get_alb_url)
    if [ ! -z "$ALB_URL" ]; then
        echo -e "\n${PURPLE}🎮 Aplicação:${NC}"
        echo -e "   Mario Game: $ALB_URL"
        echo -e "   Health Check: $ALB_URL/health"
    fi
}

# Função principal
case $ACTION in
    "status")
        check_status
        ;;
    "traces")
        list_traces
        ;;
    "generate")
        generate_traces
        ;;
    "monitor")
        monitor_traces
        ;;
    "console")
        show_console
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        echo -e "${RED}❌ Ação inválida: $ACTION${NC}"
        show_help
        exit 1
        ;;
esac

echo -e "\n${GREEN}🎯 Operação concluída!${NC}"
