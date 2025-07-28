#!/bin/bash

# Script final para verificar X-Ray
set -e

PROFILE="bedhock"
REGION="us-east-1"

echo "🔍 Verificação Final do X-Ray"

# 1. Verificar se o serviço está rodando
echo "1. Verificando containers ECS..."
aws ecs describe-services --cluster mario-game-prod-cluster --services mario-game-prod-service --profile $PROFILE --region $REGION --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' --output table

# 2. Verificar containers específicos
echo -e "\n2. Verificando containers na task..."
TASK_ARN=$(aws ecs list-tasks --cluster mario-game-prod-cluster --service-name mario-game-prod-service --profile $PROFILE --region $REGION --query 'taskArns[0]' --output text)
aws ecs describe-tasks --cluster mario-game-prod-cluster --tasks $TASK_ARN --profile $PROFILE --region $REGION --query 'tasks[0].containers[*].{Name:name,Status:lastStatus,Health:healthStatus}' --output table

# 3. Verificar logs do X-Ray daemon
echo -e "\n3. Verificando logs do X-Ray daemon..."
aws logs describe-log-streams --log-group-name /ecs/mario-game-prod --profile $PROFILE --region $REGION --query 'logStreams[?contains(logStreamName, `xray`)].{Stream:logStreamName,LastEvent:lastEventTime}' --output table

# 4. Verificar se há traces (últimas 2 horas)
echo -e "\n4. Verificando traces existentes..."
START_TIME=$(date -d '2 hours ago' -u +%Y-%m-%dT%H:%M:%S)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)

TRACE_COUNT=$(aws xray get-trace-summaries --start-time $START_TIME --end-time $END_TIME --profile $PROFILE --region $REGION --query 'TraceSummaries | length(@)' --output text)

echo "Traces encontrados: $TRACE_COUNT"

if [ "$TRACE_COUNT" -gt 0 ]; then
    echo -e "\n✅ X-Ray está funcionando! Traces encontrados:"
    aws xray get-trace-summaries --start-time $START_TIME --end-time $END_TIME --profile $PROFILE --region $REGION --query 'TraceSummaries[*].{Id:Id,Duration:Duration,Status:Http.HttpStatus}' --output table
else
    echo -e "\n⚠️  Nenhum trace encontrado ainda."
fi

# 5. Gerar tráfego real com headers X-Ray
echo -e "\n5. Gerando tráfego real com headers X-Ray..."
ALB_URL=$(aws cloudformation describe-stacks --stack-name mario-game-prod-infrastructure --profile $PROFILE --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`ApplicationLoadBalancerURL`].OutputValue' --output text)

for i in {1..3}; do
    TRACE_ID="1-$(date +%s)-$(openssl rand -hex 12)"
    echo "Requisição $i com trace: $TRACE_ID"
    
    curl -s -H "X-Amzn-Trace-Id: Root=$TRACE_ID" "$ALB_URL/health" | head -1
    curl -s -H "X-Amzn-Trace-Id: Root=$TRACE_ID" "$ALB_URL/" > /dev/null
    
    sleep 2
done

echo -e "\n✅ Verificação concluída!"
echo -e "\n📋 Links úteis:"
echo "   Console X-Ray: https://console.aws.amazon.com/xray/home?region=$REGION#/traces"
echo "   Service Map: https://console.aws.amazon.com/xray/home?region=$REGION#/service-map"
echo "   CloudWatch Logs: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#logsV2:log-groups/log-group/\$252Fecs\$252Fmario-game-prod"

echo -e "\n💡 Dica: O X-Ray pode levar alguns minutos para mostrar traces no console."
echo "   Aguarde 2-5 minutos e verifique novamente o console."
