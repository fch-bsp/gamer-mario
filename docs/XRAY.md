# AWS X-Ray - Mario Game

Este documento descreve a implementação e uso do AWS X-Ray no projeto Mario Game.

## 🎯 Visão Geral

O AWS X-Ray está configurado para fornecer tracing distribuído da aplicação Mario Game, permitindo:

- **Rastreamento de requisições** através do ALB → ECS → Nginx
- **Análise de performance** com tempos de resposta detalhados
- **Mapeamento de serviços** visual no Service Map
- **Detecção de problemas** e gargalos na aplicação

## 🏗️ Arquitetura X-Ray

```
Internet → ALB (com X-Ray headers) → ECS Task
                                      ├── mario-game-container (Nginx)
                                      └── xray-daemon (sidecar)
                                           ↓
                                      AWS X-Ray Service
```

## 📋 Componentes Configurados

### 1. **X-Ray Daemon (Sidecar Container)**
- **Imagem**: `public.ecr.aws/xray/aws-xray-daemon:latest`
- **Porta**: 2000/UDP
- **Função**: Recebe traces dos containers e envia para o serviço X-Ray

### 2. **Nginx com Headers X-Ray**
- **Configuração**: Propaga headers `X-Amzn-Trace-Id`
- **Logs**: Formato customizado com trace IDs
- **Endpoints**: Todos os endpoints incluem headers X-Ray

### 3. **IAM Permissions**
- **Task Role**: Permissões para enviar traces
- **Execution Role**: Permissões para logs e ECR

## 🚀 Como Usar

### Comandos Principais

```bash
# Verificar status do X-Ray
./scripts/manage-xray.sh prod status

# Gerar traces de teste
./scripts/manage-xray.sh prod generate

# Monitorar traces em tempo real
./scripts/manage-xray.sh prod monitor

# Listar traces recentes
./scripts/manage-xray.sh prod traces

# Mostrar links do console
./scripts/manage-xray.sh prod console
```

### Gerar Traces Manualmente

```bash
# Gerar trace único
TRACE_ID="1-$(date +%s)-$(openssl rand -hex 12)"
curl -H "X-Amzn-Trace-Id: Root=$TRACE_ID" http://mario-game-prod-alb-546561962.us-east-1.elb.amazonaws.com/

# Gerar múltiplos traces
for i in {1..10}; do
  TRACE_ID="1-$(date +%s)-$(openssl rand -hex 12)"
  curl -H "X-Amzn-Trace-Id: Root=$TRACE_ID" http://mario-game-prod-alb-546561962.us-east-1.elb.amazonaws.com/
  sleep 2
done
```

## 🔍 Monitoramento

### Console AWS X-Ray

1. **Traces**: https://console.aws.amazon.com/xray/home?region=us-east-1#/traces
   - Lista todos os traces com detalhes de timing
   - Filtros por status, duração, URL

2. **Service Map**: https://console.aws.amazon.com/xray/home?region=us-east-1#/service-map
   - Visualização gráfica dos serviços
   - Latência e taxa de erro por serviço

3. **Analytics**: https://console.aws.amazon.com/xray/home?region=us-east-1#/analytics
   - Análise de tendências
   - Comparação de performance

### Logs CloudWatch

- **Log Group**: `/ecs/mario-game-prod`
- **X-Ray Daemon Logs**: Stream prefix `xray/`
- **Application Logs**: Stream prefix `mario-game-container/`

## 📊 Métricas e Alertas

### Métricas Disponíveis

- **Latência**: Tempo de resposta das requisições
- **Taxa de Erro**: Percentual de requisições com erro
- **Throughput**: Número de requisições por segundo
- **Disponibilidade**: Uptime do serviço

### Configurar Alertas

```bash
# Exemplo: Alerta para latência alta
aws cloudwatch put-metric-alarm \
  --alarm-name "Mario-Game-High-Latency" \
  --alarm-description "Latência alta na aplicação Mario" \
  --metric-name ResponseTime \
  --namespace AWS/X-Ray \
  --statistic Average \
  --period 300 \
  --threshold 1.0 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## 🛠️ Troubleshooting

### Problema: Traces não aparecem

**Possíveis causas:**
1. **Delay normal**: X-Ray pode levar 2-15 minutos para processar
2. **Headers ausentes**: Requisições sem `X-Amzn-Trace-Id`
3. **X-Ray daemon parado**: Container sidecar não está rodando

**Soluções:**
```bash
# Verificar status dos containers
./scripts/manage-xray.sh prod status

# Gerar traces de teste
./scripts/manage-xray.sh prod generate

# Verificar logs do X-Ray daemon
aws logs tail /ecs/mario-game-prod --filter-pattern "xray" --follow
```

### Problema: Service Map vazio

**Possíveis causas:**
1. **Poucos traces**: Service Map precisa de volume mínimo
2. **Traces muito antigos**: Usar período de tempo recente

**Soluções:**
```bash
# Gerar volume de traces
for i in {1..50}; do
  ./scripts/manage-xray.sh prod generate
  sleep 10
done
```

### Problema: Permissões IAM

**Erro comum**: `AccessDenied` para `xray:PutTraceSegments`

**Solução**: Verificar se a task role tem as permissões:
- `xray:PutTraceSegments`
- `xray:PutTelemetryRecords`
- `xray:GetSamplingRules`
- `xray:GetSamplingTargets`

## 🔧 Configurações Avançadas

### Sampling Rules

Por padrão, o X-Ray usa sampling de 1 requisição por segundo + 5% do tráfego adicional.

Para criar regras customizadas:

```json
{
  "rule_name": "mario-game-high-sampling",
  "priority": 9000,
  "fixed_rate": 0.1,
  "reservoir_size": 2,
  "service_name": "mario-game-prod",
  "service_type": "*",
  "host": "*",
  "http_method": "*",
  "url_path": "*",
  "version": 1
}
```

### Annotations e Metadata

O Nginx está configurado para incluir:

**Annotations** (indexáveis):
- `environment`: prod
- `game`: super-mario-bros

**Metadata** (não indexáveis):
- `mario_game.level`: 1-1
- `mario_game.score`: 1000
- `mario_game.lives`: 3

## 📈 Melhores Práticas

### 1. **Geração de Traces**
- Sempre incluir header `X-Amzn-Trace-Id` em requisições
- Usar trace IDs únicos para cada requisição
- Propagar trace IDs através de todos os serviços

### 2. **Monitoramento**
- Verificar traces regularmente
- Configurar alertas para latência e erros
- Usar Service Map para identificar gargalos

### 3. **Performance**
- Sampling adequado para não impactar performance
- Monitorar custos do X-Ray
- Usar filtros no console para análises específicas

### 4. **Segurança**
- Não incluir dados sensíveis em annotations
- Usar IAM roles com permissões mínimas
- Monitorar acesso aos traces

## 💰 Custos

### Pricing X-Ray (us-east-1)
- **Traces**: $5.00 por 1 milhão de traces
- **Traces analisados**: $0.50 por 1 milhão de traces
- **Retenção**: 30 dias inclusos

### Estimativa para Mario Game
- **Tráfego baixo** (1000 req/dia): ~$0.15/mês
- **Tráfego médio** (10000 req/dia): ~$1.50/mês
- **Tráfego alto** (100000 req/dia): ~$15.00/mês

## 🔗 Links Úteis

- [AWS X-Ray Documentation](https://docs.aws.amazon.com/xray/)
- [X-Ray Pricing](https://aws.amazon.com/xray/pricing/)
- [X-Ray Best Practices](https://docs.aws.amazon.com/xray/latest/devguide/xray-usage.html)
- [Troubleshooting Guide](https://docs.aws.amazon.com/xray/latest/devguide/xray-troubleshooting.html)

---

**🎮 Mario Game com X-Ray - Monitoramento completo da sua aplicação na AWS!**
