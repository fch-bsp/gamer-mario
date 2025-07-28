#!/bin/bash

# Script para monitorar traces X-Ray em tempo real
set -e

PROFILE="bedhock"
REGION="us-east-1"

echo "🔍 Monitoramento Contínuo do X-Ray"
echo "=================================="

# Função para verificar traces
check_traces() {
    local start_time=$(date -d '20 minutes ago' -u +%Y-%m-%dT%H:%M:%S)
    local end_time=$(date -u +%Y-%m-%dT%H:%M:%S)
    
    local trace_count=$(aws xray get-trace-summaries \
        --start-time $start_time \
        --end-time $end_time \
        --profile $PROFILE \
        --region $REGION \
        --query 'TraceSummaries | length(@)' \
        --output text 2>/dev/null || echo "0")
    
    echo "$trace_count"
}

# Monitorar por 10 minutos
echo "Monitorando por 10 minutos (verificando a cada 30s)..."
echo ""

for i in {1..20}; do
    TIMESTAMP=$(date '+%H:%M:%S')
    TRACE_COUNT=$(check_traces)
    
    if [ "$TRACE_COUNT" -gt 0 ]; then
        echo "✅ [$TIMESTAMP] $TRACE_COUNT traces encontrados!"
        
        # Mostrar detalhes dos traces
        echo ""
        echo "📊 Detalhes dos traces:"
        aws xray get-trace-summaries \
            --start-time $(date -d '20 minutes ago' -u +%Y-%m-%dT%H:%M:%S) \
            --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
            --profile $PROFILE \
            --region $REGION \
            --query 'TraceSummaries[*].{Id:Id,Duration:Duration,Status:Http.HttpStatus,Method:Http.HttpMethod,URL:Http.HttpURL}' \
            --output table
        
        echo ""
        echo "🎉 X-Ray está funcionando!"
        echo "📋 Console: https://console.aws.amazon.com/xray/home?region=$REGION#/traces"
        echo "🗺️  Service Map: https://console.aws.amazon.com/xray/home?region=$REGION#/service-map"
        break
    else
        echo "⏳ [$TIMESTAMP] Aguardando traces... ($i/20)"
    fi
    
    if [ $i -lt 20 ]; then
        sleep 30
    fi
done

if [ "$TRACE_COUNT" -eq 0 ]; then
    echo ""
    echo "⚠️  Nenhum trace encontrado após 10 minutos."
    echo "💡 Isso pode ser normal - o X-Ray às vezes demora mais para processar."
    echo "📋 Continue verificando o console: https://console.aws.amazon.com/xray/home?region=$REGION#/traces"
    
    # Gerar mais tráfego
    echo ""
    echo "🚀 Gerando mais tráfego para forçar traces..."
    ALB_URL=$(aws cloudformation describe-stacks \
        --stack-name mario-game-prod-infrastructure \
        --profile $PROFILE \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`ApplicationLoadBalancerURL`].OutputValue' \
        --output text)
    
    for j in {1..5}; do
        TRACE_ID="1-$(date +%s)-$(openssl rand -hex 12)"
        echo "Requisição $j com trace: $TRACE_ID"
        curl -s -H "X-Amzn-Trace-Id: Root=$TRACE_ID" "$ALB_URL/" > /dev/null
        curl -s -H "X-Amzn-Trace-Id: Root=$TRACE_ID" "$ALB_URL/health" > /dev/null
        sleep 2
    done
    
    echo "✅ Mais 10 requisições enviadas!"
fi

echo ""
echo "🎯 Monitoramento concluído!"
