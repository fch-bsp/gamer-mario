#!/bin/bash

# Mario Game - Deploy Completo
# Cria toda a infraestrutura e aplicação do zero

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
IMAGE_TAG=${2:-v1.0}
REGION="us-east-1"
PROFILE="bedhock"

echo -e "${PURPLE}🚀 Mario Game - Deploy Completo${NC}"
echo -e "${BLUE}=================================${NC}"
echo -e "${YELLOW}Ambiente: $ENVIRONMENT${NC}"
echo -e "${YELLOW}Imagem: $IMAGE_TAG${NC}"
echo -e "${YELLOW}Região: $REGION${NC}"
echo -e "${YELLOW}Profile: $PROFILE${NC}"
echo -e "${BLUE}=================================${NC}"

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar dependências
echo -e "${BLUE}🔍 Verificando dependências...${NC}"
if ! command_exists aws; then
    echo -e "${RED}❌ AWS CLI não encontrado${NC}"
    exit 1
fi

if ! command_exists docker; then
    echo -e "${RED}❌ Docker não encontrado${NC}"
    exit 1
fi

# Obter Account ID
echo -e "${BLUE}🔍 Obtendo Account ID...${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --profile $PROFILE --query Account --output text)
echo -e "${GREEN}✅ Account ID: $ACCOUNT_ID${NC}"

# ETAPA 1: Build da imagem Docker
echo -e "\n${GREEN}🐳 ETAPA 1: Build da Imagem Docker${NC}"
echo -e "${BLUE}----------------------------------${NC}"
echo -e "${YELLOW}📦 Fazendo build da imagem...${NC}"

docker build -f docker/Dockerfile -t mario-game:$IMAGE_TAG .

echo -e "${GREEN}✅ Build concluído com sucesso!${NC}"
echo -e "${GREEN}📋 Imagem criada: mario-game:$IMAGE_TAG${NC}"

# ETAPA 2: Criar ECR e fazer push
echo -e "\n${GREEN}📦 ETAPA 2: ECR Repository e Push${NC}"
echo -e "${BLUE}----------------------------------${NC}"

# Criar ECR repository se não existir
echo -e "${BLUE}📦 Verificando/criando ECR repository...${NC}"
aws ecr describe-repositories --repository-names mario-game --profile $PROFILE --region $REGION >/dev/null 2>&1 || {
    echo -e "${YELLOW}📦 Criando ECR repository...${NC}"
    aws ecr create-repository --repository-name mario-game --profile $PROFILE --region $REGION >/dev/null
}
echo -e "${GREEN}✅ ECR repository pronto${NC}"

# Login no ECR
echo -e "${BLUE}🔐 Fazendo login no ECR...${NC}"
aws ecr get-login-password --profile $PROFILE --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Tag e push da imagem
echo -e "${BLUE}🏷️  Fazendo tag da imagem para ECR...${NC}"
docker tag mario-game:$IMAGE_TAG $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/mario-game:$IMAGE_TAG
docker tag mario-game:$IMAGE_TAG $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/mario-game:latest

echo -e "${BLUE}⬆️  Fazendo push da imagem para ECR...${NC}"
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/mario-game:$IMAGE_TAG
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/mario-game:latest

echo -e "${GREEN}✅ Push concluído com sucesso!${NC}"

# ETAPA 3: Deploy da Infraestrutura
echo -e "\n${GREEN}🏗️  ETAPA 3: Deploy da Infraestrutura${NC}"
echo -e "${BLUE}------------------------------------${NC}"

STACK_NAME="mario-game-$ENVIRONMENT-infrastructure"
echo -e "${YELLOW}📦 Fazendo deploy da stack: $STACK_NAME${NC}"

aws cloudformation deploy \
    --template-file cloudformation/infrastructure/vpc-alb.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides Environment=$ENVIRONMENT \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --region $REGION

echo -e "${GREEN}✅ Infraestrutura criada com sucesso${NC}"

# ETAPA 4: Deploy do ECS
echo -e "\n${GREEN}⚙️  ETAPA 4: Deploy do ECS${NC}"
echo -e "${BLUE}---------------------------${NC}"

ECS_STACK_NAME="mario-game-$ENVIRONMENT-ecs"
IMAGE_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/mario-game:$IMAGE_TAG"

echo -e "${YELLOW}📦 Fazendo deploy da stack ECS: $ECS_STACK_NAME${NC}"
echo -e "${YELLOW}🖼️  Usando imagem: $IMAGE_URI${NC}"

aws cloudformation deploy \
    --template-file cloudformation/ecs/ecs-cluster.yaml \
    --stack-name $ECS_STACK_NAME \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
        ImageUri=$IMAGE_URI \
        TaskCpu=512 \
        TaskMemory=1024 \
    --capabilities CAPABILITY_IAM \
    --profile $PROFILE \
    --region $REGION

echo -e "${GREEN}✅ ECS criado com sucesso${NC}"

# ETAPA 5: Obter URL da aplicação
echo -e "\n${GREEN}🌐 ETAPA 5: Informações da Aplicação${NC}"
echo -e "${BLUE}------------------------------------${NC}"

ALB_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --profile $PROFILE \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerURL`].OutputValue' \
    --output text)

echo -e "${GREEN}✅ Deploy completo realizado com sucesso!${NC}"

# Aguardar health check
echo -e "\n${YELLOW}⏳ Aguardando health check passar...${NC}"
echo -e "${YELLOW}   Isso pode levar alguns minutos...${NC}"

for i in {1..30}; do
    if curl -s -f "$ALB_URL/health" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Health check passou!${NC}"
        break
    fi
    echo -e "${YELLOW}   Tentativa $i/30 - aguardando...${NC}"
    sleep 10
done

# Resultado final
echo -e "\n${PURPLE}🎉 DEPLOY COMPLETO REALIZADO COM SUCESSO! 🎉${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}🌐 Aplicação disponível em:${NC}"
echo -e "${YELLOW}   $ALB_URL${NC}"
echo -e "${GREEN}🖼️  Imagem: $IMAGE_URI${NC}"
echo -e "${GREEN}📊 Ambiente: $ENVIRONMENT${NC}"

echo -e "\n${BLUE}📋 Para monitorar:${NC}"
echo -e "   aws ecs describe-services --cluster mario-game-$ENVIRONMENT-cluster --services mario-game-$ENVIRONMENT-service --profile $PROFILE --region $REGION"

echo -e "\n${BLUE}📋 Para destruir tudo:${NC}"
echo -e "   ./scripts/destroy.sh $ENVIRONMENT"

echo -e "\n${GREEN}🎮 Divirta-se jogando Super Mario Bros na AWS! 🎮${NC}"
