# Multi-stage build para otimizar o tamanho da imagem
FROM nginx:alpine AS production

# Metadados da imagem
LABEL maintainer="fernando@example.com"
LABEL description="Super Mario Bros Game - ECS Optimized"
LABEL version="1.0"

# Criar usuário não-root para segurança
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Copiar arquivos da aplicação
COPY app /usr/share/nginx/html

# Configuração customizada do Nginx
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Criar diretórios necessários e ajustar permissões
RUN mkdir -p /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
    chown -R appuser:appgroup /tmp /usr/share/nginx/html

# Expor porta 8080 (não-privilegiada)
EXPOSE 8080

# Usar usuário não-root
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Comando para iniciar o Nginx
CMD ["nginx", "-g", "daemon off;"]
