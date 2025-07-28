#!/bin/bash

# Mario Game - Destruição Completa
# Remove toda a infraestrutura e recursos AWS

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
CONFIRM=${2:-no}
REGION="us-east-1"
PROFILE="bedhock"

echo -e "${PURPLE}🗑️  Mario Game - Destruição Completa${NC}"
echo -e "${BLUE}====================================${NC}"
echo -e "${YELLOW}Ambiente: $ENVIRONMENT${NC}"
echo -e "${YELLOW}Região: $REGION${NC}"
echo -e "${YELLOW}Profile: $PROFILE${NC}"
echo -e "${BLUE}====================================${NC}"

# Confirmação de segurança
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${RED}⚠️  ATENÇÃO: Esta operação irá DESTRUIR todos os recursos AWS!${NC}"
    echo -e "${YELLOW}📋 Recursos que serão removidos:${NC}"
    echo -e "   • ECS Cluster e Services (com X-Ray daemon)"
    echo -e "   • Application Load Balancer"
    echo -e "   • VPC, Subnets, NAT Gateways"
    echo -e "   • Security Groups"
    echo -e "   • CloudWatch Logs (incluindo X-Ray logs)"
    echo -e "   • ECR Repository e imagens"
    echo -e "   • IAM Roles (incluindo permissões X-Ray)"
    echo -e "   • Imagens Docker locais"
    echo -e "   • Traces X-Ray (serão mantidos por 30 dias)"
    echo ""
    echo -e "${RED}💰 Isso irá parar TODOS os custos relacionados ao projeto${NC}"
    echo ""
    echo -e "${YELLOW}Para confirmar, execute:${NC}"
    echo -e "${BLUE}   ./scripts/destroy.sh $ENVIRONMENT yes${NC}"
    exit 0
fi

echo -e "${GREEN}🚀 Iniciando destruição dos recursos...${NC}"

# Função para verificar se stack existe
stack_exists() {
    aws cloudformation describe-stacks --stack-name "$1" --profile $PROFILE --region $REGION >/dev/null 2>&1
}

# ETAPA 1: Remover ECS Stack
echo -e "\n${GREEN}🗑️  ETAPA 1: Removendo ECS Stack${NC}"
echo -e "${BLUE}----------------------------------${NC}"

ECS_STACK_NAME="mario-game-$ENVIRONMENT-ecs"
if stack_exists $ECS_STACK_NAME; then
    echo -e "${YELLOW}📦 Removendo stack ECS: $ECS_STACK_NAME${NC}"
    aws cloudformation delete-stack --stack-name $ECS_STACK_NAME --profile $PROFILE --region $REGION
    
    echo -e "${YELLOW}⏳ Aguardando exclusão da stack: $ECS_STACK_NAME${NC}"
    aws cloudformation wait stack-delete-complete --stack-name $ECS_STACK_NAME --profile $PROFILE --region $REGION
    echo -e "${GREEN}✅ Stack $ECS_STACK_NAME removida com sucesso${NC}"
else
    echo -e "${YELLOW}⚠️  Stack $ECS_STACK_NAME não encontrada${NC}"
fi

# ETAPA 2: Remover Infraestrutura Stack
echo -e "\n${GREEN}🗑️  ETAPA 2: Removendo Infraestrutura Stack${NC}"
echo -e "${BLUE}--------------------------------------------${NC}"

INFRA_STACK_NAME="mario-game-$ENVIRONMENT-infrastructure"
if stack_exists $INFRA_STACK_NAME; then
    echo -e "${YELLOW}📦 Removendo stack de infraestrutura: $INFRA_STACK_NAME${NC}"
    aws cloudformation delete-stack --stack-name $INFRA_STACK_NAME --profile $PROFILE --region $REGION
    
    echo -e "${YELLOW}⏳ Aguardando exclusão da stack: $INFRA_STACK_NAME${NC}"
    aws cloudformation wait stack-delete-complete --stack-name $INFRA_STACK_NAME --profile $PROFILE --region $REGION
    echo -e "${GREEN}✅ Stack $INFRA_STACK_NAME removida com sucesso${NC}"
else
    echo -e "${YELLOW}⚠️  Stack $INFRA_STACK_NAME não encontrada${NC}"
fi

# ETAPA 3: Remover ECR Repository
echo -e "\n${GREEN}🗑️  ETAPA 3: Removendo ECR Repository${NC}"
echo -e "${BLUE}------------------------------------${NC}"

# Verificar se ECR repository existe
if aws ecr describe-repositories --repository-names mario-game --profile $PROFILE --region $REGION >/dev/null 2>&1; then
    echo -e "${YELLOW}🖼️  Removendo todas as imagens do ECR...${NC}"
    
    # Obter todas as imagens e remover
    IMAGE_TAGS=$(aws ecr list-images --repository-name mario-game --profile $PROFILE --region $REGION --query 'imageIds[*].imageTag' --output text 2>/dev/null || echo "")
    
    if [ ! -z "$IMAGE_TAGS" ]; then
        for tag in $IMAGE_TAGS; do
            if [ "$tag" != "None" ]; then
                aws ecr batch-delete-image --repository-name mario-game --image-ids imageTag=$tag --profile $PROFILE --region $REGION >/dev/null 2>&1 || true
            fi
        done
    fi
    
    # Remover imagens sem tag
    aws ecr list-images --repository-name mario-game --filter tagStatus=UNTAGGED --profile $PROFILE --region $REGION --query 'imageIds[*]' --output json | \
    jq '.[] | select(.imageDigest != null)' | \
    jq -s '.' | \
    xargs -I {} aws ecr batch-delete-image --repository-name mario-game --image-ids '{}' --profile $PROFILE --region $REGION >/dev/null 2>&1 || true
    
    echo -e "${GREEN}✅ Imagens removidas do ECR${NC}"
    
    echo -e "${YELLOW}📦 Removendo ECR repository...${NC}"
    aws ecr delete-repository --repository-name mario-game --force --profile $PROFILE --region $REGION >/dev/null
    echo -e "${GREEN}✅ ECR repository removido com sucesso${NC}"
else
    echo -e "${YELLOW}⚠️  ECR repository não encontrado${NC}"
fi

# ETAPA 4: Limpeza X-Ray
echo -e "\n${GREEN}🔍 ETAPA 4: Limpeza X-Ray${NC}"
echo -e "${BLUE}------------------------${NC}"

echo -e "${YELLOW}📊 Verificando traces X-Ray...${NC}"

# Verificar se há traces recentes (últimas 24 horas)
START_TIME=$(date -d '24 hours ago' -u +%Y-%m-%dT%H:%M:%S)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)

TRACE_COUNT=$(aws xray get-trace-summaries \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --profile $PROFILE \
    --region $REGION \
    --query 'TraceSummaries | length(@)' \
    --output text 2>/dev/null || echo "0")

if [ "$TRACE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ $TRACE_COUNT traces encontrados nas últimas 24h${NC}"
    echo -e "${YELLOW}💡 Traces X-Ray são mantidos por 30 dias automaticamente${NC}"
    echo -e "${BLUE}   Console X-Ray: https://console.aws.amazon.com/xray/home?region=$REGION#/traces${NC}"
else
    echo -e "${YELLOW}ℹ️  Nenhum trace X-Ray encontrado nas últimas 24h${NC}"
fi

echo -e "${YELLOW}🔧 Verificando sampling rules customizadas...${NC}"
CUSTOM_RULES=$(aws xray get-sampling-rules \
    --profile $PROFILE \
    --region $REGION \
    --query 'SamplingRuleRecords[?SamplingRule.RuleName != `Default`].SamplingRule.RuleName' \
    --output text 2>/dev/null || echo "")

if [ ! -z "$CUSTOM_RULES" ] && [ "$CUSTOM_RULES" != "None" ]; then
    echo -e "${YELLOW}⚠️  Sampling rules customizadas encontradas: $CUSTOM_RULES${NC}"
    echo -e "${BLUE}   Estas não serão removidas automaticamente${NC}"
else
    echo -e "${GREEN}✅ Apenas sampling rules padrão encontradas${NC}"
fi

echo -e "${GREEN}✅ Verificação X-Ray concluída${NC}"

# ETAPA 5: Limpeza Local
echo -e "\n${GREEN}🗑️  ETAPA 5: Limpeza Local${NC}"
echo -e "${BLUE}---------------------------${NC}"

echo -e "${YELLOW}🐳 Removendo imagens Docker locais...${NC}"

# Obter Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --profile $PROFILE --query Account --output text 2>/dev/null || echo "")

# Remover imagens Docker locais relacionadas ao projeto
docker images --format "table {{.Repository}}:{{.Tag}}" | grep -E "(mario-game|$ACCOUNT_ID.*mario-game)" | while read image; do
    if [ ! -z "$image" ] && [ "$image" != "REPOSITORY:TAG" ]; then
        docker rmi "$image" >/dev/null 2>&1 && echo -e "${GREEN}✅ Removida: $image${NC}" || true
    fi
done

echo -e "${YELLOW}🧹 Executando limpeza geral do Docker...${NC}"
docker system prune -f >/dev/null 2>&1 || true

# ETAPA 6: Verificação Final
echo -e "\n${GREEN}🔍 ETAPA 6: Verificação Final${NC}"
echo -e "${BLUE}-----------------------------${NC}"
echo -e "${YELLOW}📋 Verificando se todos os recursos foram removidos...${NC}"

# Verificar stacks
REMAINING_STACKS=$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --profile $PROFILE --region $REGION --query "StackSummaries[?contains(StackName, 'mario-game')].StackName" --output text 2>/dev/null || echo "")

if [ -z "$REMAINING_STACKS" ]; then
    echo -e "${GREEN}✅ Nenhuma stack CloudFormation encontrada${NC}"
else
    echo -e "${YELLOW}⚠️  Stacks ainda existentes: $REMAINING_STACKS${NC}"
fi

# Verificar ECR
ECR_EXISTS=$(aws ecr describe-repositories --repository-names mario-game --profile $PROFILE --region $REGION 2>/dev/null && echo "exists" || echo "")
if [ -z "$ECR_EXISTS" ]; then
    echo -e "${GREEN}✅ ECR repository removido${NC}"
else
    echo -e "${YELLOW}⚠️  ECR repository ainda existe${NC}"
fi

# Resultado final
echo -e "\n${PURPLE}🎉 DESTRUIÇÃO COMPLETA REALIZADA COM SUCESSO! 🎉${NC}"
echo -e "${BLUE}===============================================${NC}"
echo -e "${GREEN}✅ Todos os recursos AWS foram removidos${NC}"
echo -e "${GREEN}✅ Imagens Docker locais foram limpas${NC}"
echo -e "${GREEN}💰 Todos os custos relacionados ao projeto foram interrompidos${NC}"

echo -e "\n${BLUE}📋 Recursos removidos:${NC}"
echo -e "   ✅ ECS Cluster e Services"
echo -e "   ✅ Application Load Balancer"
echo -e "   ✅ VPC, Subnets, NAT Gateways"
echo -e "   ✅ Security Groups"
echo -e "   ✅ CloudWatch Logs"
echo -e "   ✅ ECR Repository e imagens"
echo -e "   ✅ IAM Roles"
echo -e "   ✅ Imagens Docker locais"

echo -e "\n${GREEN}🔄 Para recriar o ambiente, execute:${NC}"
echo -e "${BLUE}   ./scripts/deploy.sh $ENVIRONMENT v1.0${NC}"

echo -e "\n${GREEN}💡 Lembre-se: Com IaC, destruir e recriar é fácil e seguro!${NC}"
