#!/usr/bin/env bash
# Despliega decisionador.es al borde compartido (Caddy) del VPS.
# Uso: ./deploy.sh   (variables opcionales: DEPLOY_HOST)

set -euo pipefail

HOST="${DEPLOY_HOST:-lumbre}"
DEST=/srv/edge/conf.d/static/decisionador
CADDY_DEST=/srv/edge/conf.d/decisionador.caddy
CADDY_LOCAL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/deploy/decisionador.caddy"

echo "==> Creando directorio remoto $DEST"
ssh "$HOST" mkdir -p "$DEST"

echo "==> Sincronizando site/ con $HOST:$DEST"
rsync -az --delete site/ "$HOST:$DEST/"

echo "==> Comparando fragmento de Caddy remoto con el local"
REMOTO_TMP="$(mktemp)"
trap 'rm -f "$REMOTO_TMP"' EXIT

if ssh "$HOST" "cat $CADDY_DEST" > "$REMOTO_TMP" 2>/dev/null; then
	EXISTIA_REMOTO=1
else
	EXISTIA_REMOTO=0
	: > "$REMOTO_TMP"
fi

if [ "$EXISTIA_REMOTO" -eq 0 ] || ! diff -q "$CADDY_LOCAL" "$REMOTO_TMP" >/dev/null 2>&1; then
	echo "==> El fragmento de Caddy difiere o no existe: actualizando"

	if [ "$EXISTIA_REMOTO" -eq 1 ]; then
		BACKUP="$CADDY_DEST.bak-$(date +%Y%m%d%H%M%S)"
		echo "==> Backup remoto en $BACKUP"
		ssh "$HOST" cp -a "$CADDY_DEST" "$BACKUP"
	fi

	echo "==> Subiendo nuevo fragmento con scp"
	scp "$CADDY_LOCAL" "$HOST:$CADDY_DEST"

	echo "==> Validando configuración de Caddy"
	if ! ssh "$HOST" docker exec edge-caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; then
		echo "==> Validación fallida: restaurando backup"
		if [ "$EXISTIA_REMOTO" -eq 1 ]; then
			ssh "$HOST" cp -a "$BACKUP" "$CADDY_DEST"
		else
			ssh "$HOST" rm -f "$CADDY_DEST"
		fi
		echo "ERROR: la configuración de Caddy no valida, se ha restaurado el estado anterior" >&2
		exit 1
	fi

	echo "==> Recargando Caddy (reload, no restart)"
	ssh "$HOST" docker exec edge-caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
else
	echo "==> El fragmento de Caddy ya está al día, no hace falta recargar"
fi

echo "==> Smoke test HTTP (se espera 200 o 308)"
CODIGO_HTTP="$(ssh "$HOST" curl -s -o /dev/null -w '%{http_code}' -H 'Host: decisionador.es' http://127.0.0.1/)"
if [ "$CODIGO_HTTP" = "200" ] || [ "$CODIGO_HTTP" = "308" ]; then
	echo "==> OK: HTTP devolvió $CODIGO_HTTP"
else
	echo "ERROR: smoke test HTTP devolvió $CODIGO_HTTP (se esperaba 200 o 308)" >&2
	exit 1
fi

echo "==> Smoke test HTTPS (puede fallar si el DNS aún no ha propagado)"
if ssh "$HOST" curl -sk --resolve decisionador.es:443:127.0.0.1 https://decisionador.es/ | grep -q DECISIONADOR; then
	echo "==> OK: el body de HTTPS contiene DECISIONADOR"
else
	echo "AVISO: no se pudo confirmar el contenido por HTTPS (el certificado puede no existir aún)"
fi

echo "==> Despliegue completado"
