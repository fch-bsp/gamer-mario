#!/bin/sh

# Script para enviar traces para X-Ray daemon
# Este script pode ser chamado pelo Nginx via lua ou por um processo separado

XRAY_DAEMON_ADDRESS=${XRAY_DAEMON_ADDRESS:-"127.0.0.1:2000"}
SERVICE_NAME=${AWS_XRAY_TRACING_NAME:-"mario-game-prod"}

# Função para gerar trace ID
generate_trace_id() {
    TIMESTAMP=$(date +%s)
    RANDOM_ID=$(openssl rand -hex 12)
    echo "1-${TIMESTAMP}-${RANDOM_ID}"
}

# Função para enviar trace segment
send_trace_segment() {
    local trace_id=$1
    local segment_id=$2
    local start_time=$3
    local end_time=$4
    local http_status=$5
    local http_method=$6
    local http_url=$7
    
    # Criar segment JSON
    SEGMENT_JSON=$(cat <<EOF
{
    "trace_id": "${trace_id}",
    "id": "${segment_id}",
    "name": "${SERVICE_NAME}",
    "start_time": ${start_time},
    "end_time": ${end_time},
    "http": {
        "request": {
            "method": "${http_method}",
            "url": "${http_url}"
        },
        "response": {
            "status": ${http_status}
        }
    },
    "service": {
        "name": "${SERVICE_NAME}",
        "version": "1.0"
    },
    "aws": {
        "ecs": {
            "container": "mario-game-container"
        }
    }
}
EOF
)

    # Enviar para X-Ray daemon via UDP
    echo "$SEGMENT_JSON" | nc -u -w1 127.0.0.1 2000 2>/dev/null || true
}

# Exemplo de uso
if [ "$1" = "test" ]; then
    TRACE_ID=$(generate_trace_id)
    SEGMENT_ID=$(openssl rand -hex 8)
    START_TIME=$(date +%s.%3N)
    sleep 0.1
    END_TIME=$(date +%s.%3N)
    
    send_trace_segment "$TRACE_ID" "$SEGMENT_ID" "$START_TIME" "$END_TIME" "200" "GET" "/"
    echo "Test trace sent: $TRACE_ID"
fi
