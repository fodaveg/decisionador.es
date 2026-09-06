# decisionador.es

Una página de una sola pantalla que decide por ti. Pincha «Sí / No» y sale
**SÍ** o **NO** al azar; pincha «Varias opciones» y sale **OPCIÓN 1** u
**OPCIÓN 2**. En cada click cambia también la distribución de colores.

Sin frameworks, sin dependencias externas, sin peticiones a terceros: todo
el HTML, CSS y JS vive en `site/index.html`, y la única tipografía
(Archivo Black) está autoalojada en `site/fonts/archivo-black.woff2`.

## Estructura

- `site/` — la web estática que se despliega tal cual.
- `deploy/decisionador.caddy` — copia canónica del fragmento de Caddy del
  servidor (`/srv/edge/conf.d/decisionador.caddy`).
- `deploy.sh` — sincroniza `site/` y el fragmento de Caddy con el VPS.

## Despliegue

```sh
DEPLOY_HOST=lumbre ./deploy.sh
```

Sincroniza `site/` por rsync, sube el fragmento de Caddy si cambió,
valida y recarga Caddy (nunca lo reinicia), y termina con un smoke test
sobre HTTP y HTTPS.

## Licencia

MIT. Ver [`LICENSE`](LICENSE).
