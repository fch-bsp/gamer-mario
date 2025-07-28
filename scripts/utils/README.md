# Scripts Auxiliares - Mario Game

Esta pasta contém scripts auxiliares para troubleshooting e funcionalidades avançadas do X-Ray.

## 📋 Scripts Disponíveis

### 🔧 **manage-xray.sh**
Script completo para gerenciar X-Ray com múltiplas funcionalidades:

```bash
# Verificar status completo
./scripts/utils/manage-xray.sh prod status

# Gerar traces de teste
./scripts/utils/manage-xray.sh prod generate

# Monitorar traces em tempo real
./scripts/utils/manage-xray.sh prod monitor

# Listar traces recentes
./scripts/utils/manage-xray.sh prod traces

# Mostrar links do console
./scripts/utils/manage-xray.sh prod console
```

### 🧪 **Scripts de Teste X-Ray**

#### `enable-xray-alb.sh`
- Gera 30 traces com diferentes endpoints
- Aguarda processamento e verifica resultados
- Útil para teste inicial do X-Ray

#### `xray-final-solution.sh`
- Verificação completa da configuração X-Ray
- Diagnóstico avançado de problemas
- Teste de conectividade

#### `monitor-xray.sh`
- Monitoramento contínuo por 10 minutos
- Verificação a cada 30 segundos
- Geração adicional de tráfego se necessário

#### `generate-traces.sh` / `generate-traces-simple.sh`
- Scripts para gerar traces sintéticos
- Úteis para testar o X-Ray daemon

#### `test-xray.sh` / `test-xray-final.sh`
- Scripts de teste básico do X-Ray
- Verificação de funcionalidade

## 💡 Quando Usar

### **Scripts Principais (pasta raiz)**
Use para operações normais:
- `./scripts/deploy.sh` - Deploy completo
- `./scripts/destroy.sh` - Destruir recursos

### **Scripts Auxiliares (esta pasta)**
Use para troubleshooting ou funcionalidades avançadas:
- Problemas com X-Ray
- Testes específicos
- Monitoramento detalhado
- Diagnóstico de problemas

## 🚨 Importante

**Os scripts principais já incluem todas as funcionalidades essenciais do X-Ray.**

Estes scripts auxiliares são para casos específicos onde você precisa de:
- Troubleshooting avançado
- Testes detalhados
- Monitoramento específico
- Diagnóstico de problemas

## 📖 Documentação

Para informações completas sobre X-Ray, consulte:
- `../docs/XRAY.md` - Guia completo do X-Ray
- `../README.md` - Documentação principal do projeto

---

**💡 Dica**: Na maioria dos casos, você só precisará dos scripts principais (`deploy.sh` e `destroy.sh`). Use estes scripts auxiliares apenas quando necessário para troubleshooting ou testes específicos.
