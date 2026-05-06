# Recon Dashboard — Bug Bounty & Red Team Automation

> Pipeline de reconocimiento automatizado con dashboard web para gestionar campañas de Bug Bounty y Red Team. Un solo comando, cobertura completa.

![Bash](https://img.shields.io/badge/Bash-5-4EAA25?logo=gnubash) ![Python](https://img.shields.io/badge/Python-3.11-blue?logo=python) ![Streamlit](https://img.shields.io/badge/Streamlit-1.x-FF4B4B?logo=streamlit) ![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)

---

## ¿Qué incluye?

### `recon2.sh` — Pipeline de reconocimiento automatizado (v3)

Script Bash de ~200 líneas que encadena **20+ herramientas** del ecosistema OSINT/recon en un pipeline ordenado, con spinner de progreso, tiempos por fase y resumen ejecutivo automático al finalizar.

**Fases del pipeline:**

| Fase | Herramientas | Qué hace |
|------|-------------|---------|
| Enumeración de subdominios | subfinder, amass, alterx, cero, katana, GAU/Wayback, ctfr, theHarvester | Descubrimiento pasivo y activo de subdominios desde múltiples fuentes |
| Resolución DNS | shuffledns, dnsx | Valida y resuelve subdominios contra una lista de resolvers públicos |
| HTTP probing | httpx | Detecta webs vivas, status codes, tecnologías y títulos |
| Screenshots | gowitness | Captura pantallas de todos los hosts web vivos |
| Detección WAF | wafw00f, whatweb | Identifica WAFs y tecnologías de cada objetivo |
| Directory fuzzing | ffuf + SecLists | Descubrimiento de rutas ocultas en paralelo sobre todos los subdominios |
| Escaneo de puertos | masscan + nmap | masscan para velocidad, nmap -sV -sC para detalle de servicios |
| Vulnerabilidades | nuclei (-s critical,high,medium) | Escaneo de CVEs y templates custom sobre todos los objetivos |
| Subdomain takeover | subzy | Detecta subdominios vulnerables a takeover |
| SSL/TLS | testssl | Analiza la configuración SSL de cada host |
| Email spoofing | spoofcheck | Verifica SPF, DMARC y DKIM del dominio objetivo |
| Brechas de datos | HIBP API | Comprueba emails encontrados contra Have I Been Pwned |

Al finalizar genera automáticamente un **resumen ejecutivo** con conteos de subdominios, hosts vivos, puertos abiertos, vulnerabilidades críticas/altas y takeovers detectados.

### `app.py` — Dashboard web (Streamlit)

Panel de control para visualizar y gestionar el historial de escaneos:

- Sidebar con historial de targets y escaneos por fecha
- Visualización del resumen ejecutivo por escaneo
- Navegación entre campañas sin tocar la línea de comandos
- Desplegado con Docker para acceso web local

## Uso

### Pipeline de reconocimiento

```bash
chmod +x recon2.sh
./recon2.sh ejemplo.com
```

El script guarda los resultados en `~/recopilacion/ejemplo.com/YYYY_MM_DD-HH_MM/`.

**Variables opcionales:**
```bash
HIBP_API_KEY=tu-api-key ./recon2.sh ejemplo.com
```

### Dashboard web

```bash
docker compose up -d
```

Abre `http://localhost:8501` para ver el historial de escaneos.

## Herramientas requeridas

Instala el ecosistema ProjectDiscovery + herramientas estándar:

```bash
# ProjectDiscovery tools
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/projectdiscovery/katana/cmd/katana@latest
go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest
go install -v github.com/projectdiscovery/alterx/cmd/alterx@latest
go install -v github.com/projectdiscovery/cero@latest
go install -v github.com/smaranchand/bucky/cmd/bucky@latest
go install -v github.com/lc/subzy@latest
go install -v github.com/tomnomnom/unfurl@latest
go install -v github.com/lc/gau/v2/cmd/gau@latest
go install -v github.com/sensepost/gowitness@latest

# Otras herramientas
sudo apt install -y nmap masscan amass ffuf wafw00f whatweb testssl.sh theharvester
pip3 install spoofcheck
```

## Estructura de resultados

```
~/recopilacion/
└── ejemplo.com/
    └── 2025_01_15-14_30/
        ├── subfinder.txt          # Subdominios (subfinder)
        ├── amass.txt              # Subdominios (amass)
        ├── subdominios_raw.txt    # Todos los subdominios sin filtrar
        ├── objetivos.txt          # Hosts web vivos
        ├── httpx_full.txt         # Detalle de HTTP probing
        ├── nuclei_vulns.txt       # Vulnerabilidades encontradas
        ├── subzy_takeovers.txt    # Posibles takeovers
        ├── emails.txt             # Emails encontrados
        ├── ips_unicas.txt         # IPs únicas
        ├── ffuf/                  # Resultados de directory fuzzing
        ├── puertos/               # Resultados nmap/masscan por IP
        ├── gowitness_screens/     # Screenshots
        └── ejemplo.com-resumen-final.txt  # Resumen ejecutivo
```

## Notas de uso ético

Este toolset está diseñado exclusivamente para:
- Programas de Bug Bounty con scope definido
- Pentesting con autorización escrita del cliente
- Entornos de laboratorio y CTFs

**Úsalo solo sobre sistemas para los que tengas permiso explícito.**

## Licencia

MIT — para uso en Bug Bounty autorizado, pentesting profesional y entornos de laboratorio.
