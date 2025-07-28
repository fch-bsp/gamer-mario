# Mario Game - AWS ECS Deployment

Este projeto contém o jogo Super Mario Bros configurado para deploy no Amazon ECS com infraestrutura completa na AWS usando **Infrastructure as Code (IaC)**.

## 🎯 Arquitetura

```
Internet → ALB → ECS Fargate Tasks (Private Subnets) → ECR
                      ↓
                CloudWatch Logs
```

## 📁 Estrutura do Projeto

```
mario-ecs/
├── app/                           # Arquivos da aplicação web
├── docker/                       # Configurações Docker
│   ├── Dockerfile                # Dockerfile otimizado (Nginx Alpine)
│   ├── nginx.conf                # Configuração do Nginx
│   └── .dockerignore             # Arquivos ignorados no build
├── cloudformation/               # Templates CloudFormation (IaC)
│   ├── infrastructure/           # VPC, ALB, Security Groups
│   │   └── vpc-alb.yaml
│   └── ecs/                      # ECS Cluster, Tasks, Services
│       └── ecs-cluster.yaml
├── scripts/                      # Scripts de automação (SIMPLIFICADOS)
│   ├── deploy.sh                 # 🚀 Deploy completo (tudo em um)
│   └── destroy.sh                # 🗑️ Destruir tudo (limpeza total)
└── README.md                     # Este arquivo
```

## 🚀 Comandos Principais

### 🏗️ Deploy Completo (Criar tudo do zero)
```bash
cd mario-ecs
./scripts/deploy.sh [environment] [image-tag]

# Exemplos:
./scripts/deploy.sh prod v1.0
./scripts/deploy.sh dev v2.0
```

### 🗑️ Destruir Todos os Recursos (Parar custos)
```bash
# Confirmação necessária para segurança
./scripts/destroy.sh [environment] yes

# Exemplos:
./scripts/destroy.sh prod yes
./scripts/destroy.sh dev yes
```

### 📋 Comandos Simplificados
- **Deploy**: `./scripts/deploy.sh prod v1.0` - Cria tudo (15-20 min)
- **Destroy**: `./scripts/destroy.sh prod yes` - Remove tudo (10-15 min)

## 🏗️ Recursos AWS Criados

### Infraestrutura
- **VPC**: 10.0.0.0/16 com DNS habilitado
- **Subnets**: 2 públicas + 2 privadas (Multi-AZ)
- **NAT Gateways**: 2 para alta disponibilidade
- **Internet Gateway**: Para acesso público
- **Route Tables**: Configuradas para público/privado

### Load Balancer
- **ALB**: Application Load Balancer internet-facing
- **Target Group**: Health check em `/health`
- **Security Groups**: HTTP/HTTPS (80/443) → ECS (8080)

### ECS
- **Cluster**: Fargate com Container Insights
- **Service**: Auto Scaling (1-10 tasks)
- **Task Definition**: 256 CPU, 512 MB RAM
- **Capacity Providers**: Fargate + Fargate Spot (80% Spot)

### Monitoramento
- **CloudWatch Logs**: `/ecs/mario-game-prod`
- **Auto Scaling**: CPU (70%) e Memory (80%)
- **Health Checks**: Container + ALB

## ⚡ Otimização de Performance

### Problema Identificado
A configuração inicial (256 CPU / 512MB RAM) pode causar lentidão em jogos HTML5 devido a:
- **CPU insuficiente**: JavaScript pesado de jogos precisa de mais processamento
- **Memória limitada**: Garbage collection frequente causa travamentos
- **Nginx não otimizado**: Configuração padrão não é ideal para jogos

### Solução Aplicada
```bash
./scripts/optimize-performance.sh prod 512 1024
```

**Melhorias implementadas:**
- ⚡ **CPU**: 256 → 512 (100% mais poder de processamento)
- 🧠 **Memória**: 512MB → 1024MB (100% mais memória)
- 🌐 **Nginx otimizado**: Buffers, cache e compressão para jogos HTML5
- 🎵 **Streaming de áudio**: Headers otimizados para arquivos de som
- 📦 **Cache inteligente**: Assets estáticos com cache de 1 ano

### Configurações Recomendadas por Tipo de Aplicação

| Tipo de App | CPU | Memória | Uso |
|-------------|-----|---------|-----|
| **Site estático** | 256 | 512MB | Blogs, landing pages |
| **Jogo HTML5 simples** | 512 | 1024MB | ✅ **Atual - Mario Game** |
| **Jogo HTML5 complexo** | 1024 | 2048MB | Jogos 3D, multiplayer |
| **Aplicação pesada** | 2048 | 4096MB | Apps com muitos recursos |

## ⚙️ Configurações

### AWS
- **Região**: us-east-1 (N. Virginia)
- **Profile**: bedhock
- **Account ID**: 440744259713

### Aplicação (Otimizada)
- **CPU**: 512 (0.5 vCPU) - Otimizado para jogos HTML5
- **Memória**: 1024MB (1GB) - Otimizado para jogos HTML5
- **Porta**: 8080 (container)
- **Health Check**: `/health`
- **Usuário**: appuser (não-root)
- **Tamanho da Imagem**: ~72MB
- **Versão**: v1.3-optimized

## 🔄 Fluxos de Trabalho Simplificados

### 1. Deploy Completo (Criar ambiente)
```bash
./scripts/deploy.sh prod v1.0
```
**Tempo**: ~15-20 minutos  
**Cria**: Toda a infraestrutura + aplicação + monitoramento

### 2. Destruição Completa (Parar custos)
```bash
./scripts/destroy.sh prod yes
```
**Tempo**: ~10-15 minutos  
**Remove**: Todos os recursos e para custos

### 3. Recriação (Amanhã)
```bash
./scripts/deploy.sh prod v1.0
```
**Tempo**: ~15-20 minutos  
**Resultado**: Ambiente idêntico ao anterior

## 🔍 Monitoramento com AWS X-Ray

### Recursos Habilitados
- **X-Ray Daemon**: Sidecar container para coleta de traces
- **Service Map**: Visualização automática da arquitetura
- **Trace Analysis**: Análise detalhada de latência
- **Error Detection**: Identificação automática de erros
- **Performance Insights**: Gargalos e anomalias

### Comandos de Monitoramento
```bash
# Monitoramento geral (últimos 30 min)
./scripts/monitor-xray.sh prod 30

# Monitoramento em tempo real
watch -n 30 './scripts/monitor-xray.sh prod 5'

# Análise de performance tradicional
./scripts/analyze-performance.sh prod 30

# Diagnóstico de travamentos
./scripts/diagnose-lag.sh prod
```

### Console AWS X-Ray
- **Service Map**: https://us-east-1.console.aws.amazon.com/xray/home?region=us-east-1#/service-map
- **Traces**: https://us-east-1.console.aws.amazon.com/xray/home?region=us-east-1#/traces
- **Analytics**: https://us-east-1.console.aws.amazon.com/xray/home?region=us-east-1#/analytics

### Métricas Importantes para Jogos
- **Latência de resposta**: < 100ms
- **Taxa de erro**: < 1%
- **Tempo de carregamento**: Assets < 500ms
- **Performance durante movimento**: Sem picos de latência

## 📊 Monitoramento Tradicional (CloudWatch)

### CloudWatch Logs
```bash
aws logs tail /ecs/mario-game-prod --follow --profile bedhock --region us-east-1
```

### Status do ECS Service
```bash
aws ecs describe-services \
  --cluster mario-game-prod-cluster \
  --services mario-game-prod-service \
  --profile bedhock --region us-east-1
```

### Health Check dos Targets
```bash
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:440744259713:targetgroup/mario-game-prod-tg/XXXXXXXXX \
  --profile bedhock --region us-east-1
```

## 🧪 Teste Local

```bash
docker run -p 8080:8080 mario-game:v1.1
curl http://localhost:8080/health
# Deve retornar: healthy
```

## 💰 Gestão de Custos

### Recursos que Geram Custo
- **NAT Gateways**: ~$45/mês cada (2 = ~$90/mês)
- **ALB**: ~$16/mês + tráfego
- **ECS Fargate**: ~$0.04048/vCPU/hora + $0.004445/GB/hora
- **ECR**: $0.10/GB/mês para armazenamento

### Para Parar Custos Completamente
```bash
./scripts/destroy-all.sh prod yes
```

### Para Reduzir Custos (Manter infraestrutura)
```bash
# Reduzir tasks para 0 (manter infraestrutura)
aws ecs update-service \
  --cluster mario-game-prod-cluster \
  --service mario-game-prod-service \
  --desired-count 0 \
  --profile bedhock --region us-east-1

# Para reativar
aws ecs update-service \
  --cluster mario-game-prod-cluster \
  --service mario-game-prod-service \
  --desired-count 2 \
  --profile bedhock --region us-east-1
```

## 🚨 Troubleshooting

### Tasks não iniciam
```bash
# Verificar logs
aws logs tail /ecs/mario-game-prod --profile bedhock --region us-east-1

# Verificar eventos do serviço
aws ecs describe-services \
  --cluster mario-game-prod-cluster \
  --services mario-game-prod-service \
  --profile bedhock --region us-east-1 \
  --query 'services[0].events[0:5]'
```

### Health check falhando
```bash
# Testar health check diretamente
curl http://ALB-URL/health

# Verificar target group
aws elbv2 describe-target-health \
  --target-group-arn TARGET-GROUP-ARN \
  --profile bedhock --region us-east-1
```

### Problemas no CloudFormation
```bash
# Verificar eventos da stack
aws cloudformation describe-stack-events \
  --stack-name mario-game-prod-ecs \
  --profile bedhock --region us-east-1 \
  --query 'StackEvents[0:10].{Time:Timestamp,Status:ResourceStatus,Reason:ResourceStatusReason}'
```

## 📋 Checklist de Operações

### ✅ Deploy Inicial
- [ ] Executar `./scripts/deploy-all.sh prod v1.0`
- [ ] Verificar URL da aplicação
- [ ] Testar health check
- [ ] Verificar logs no CloudWatch

### ✅ Atualização de Aplicação
- [ ] Build nova imagem
- [ ] Push para ECR
- [ ] Executar `./scripts/update-app.sh`
- [ ] Verificar rolling deployment
- [ ] Testar nova versão

### ✅ Mudanças na Infraestrutura
- [ ] Editar templates CloudFormation
- [ ] Executar `./scripts/update-infrastructure.sh`
- [ ] Verificar changeset
- [ ] Confirmar aplicação das mudanças

### ✅ Destruição (Parar custos)
- [ ] Backup de dados importantes (se houver)
- [ ] Executar `./scripts/destroy-all.sh prod yes`
- [ ] Verificar remoção completa
- [ ] Confirmar parada de custos

## 🎮 Status Atual

**URL da Aplicação**: http://mario-game-prod-alb-1066129391.us-east-1.elb.amazonaws.com

**Status**: ✅ **OTIMIZADA COM X-RAY HABILITADO**
- ECS Service: ACTIVE
- Tasks: 2 running (Task Definition v4)
- CPU: 512 (0.5 vCPU por task)
- Memória: 1024MB (1GB por task)
- Health Check: ✅ Healthy
- Imagens estáticas: ✅ Carregando corretamente
- Performance: ✅ Otimizada para jogos HTML5
- **X-Ray**: ✅ Monitoramento avançado habilitado
- **Versão**: v1.4-xray

---

## 🎉 Comandos Rápidos

```bash
# 🚀 Deploy completo (criar tudo)
./scripts/deploy.sh prod v1.0

# 🗑️ Destruir tudo (parar custos)
./scripts/destroy.sh prod yes

# 📊 Monitorar logs (quando ativo)
aws logs tail /ecs/mario-game-prod --follow --profile bedhock --region us-east-1
```

**🎮 Divirta-se jogando Super Mario Bros na AWS!** 🎮
