#!/bin/bash
# =============================================================================
#  RECON2.SH — Pipeline de Reconocimiento Automatizado v3 (VERSIÓN DEFINITIVA)
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()    { echo -e "${CYAN}[*]${RESET} $1"; }
log_ok()      { echo -e "${GREEN}[✔]${RESET} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${RESET} $1"; }
log_error()   { echo -e "${RED}[✘]${RESET} $1"; }
log_section() { echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
                echo -e "${BOLD}${CYAN}  $1${RESET}"
                echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

NUCLEI_CONCURRENCY=25
NUCLEI_RATE=150
NUCLEI_BULK=25
FFUF_THREADS=20
FFUF_RATE=100
HTTPX_THREADS=100
MASSCAN_RATE=500
NMAP_MIN_HOSTGROUP=16
NMAP_MIN_RATE=100
NMAP_MAX_PARALLELISM=10
HIBP_API_KEY="${HIBP_API_KEY:-}"

count_lines() { if [ -f "$1" ]; then grep -c '' "$1" 2>/dev/null; else echo "0"; fi; }
escape_domain() { echo "$1" | sed 's/\./\\./g'; }

run_with_spinner() {
    local desc="$1"; shift
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local start_ts=$(date +%s)
    (
        local i=0
        while true; do
            local elapsed=$(( $(date +%s) - start_ts ))
            local m=$(( elapsed / 60 )) s=$(( elapsed % 60 ))
            printf "\r  \033[0;36m%s\033[0m %s  \033[1;33m[%dm%02ds]\033[0m" "${spin:$(( i % ${#spin} )):1}" "$desc" "$m" "$s"
            i=$(( i + 1 ))
            sleep 0.15
        done
    ) &
    local spin_pid=$!
    "$@"
    local exit_code=$?
    kill "$spin_pid" 2>/dev/null
    wait "$spin_pid" 2>/dev/null
    printf "\r\033[K"
    return $exit_code
}

recon() {
    TARGET="$1"
    TARGET_RE=$(escape_domain "$TARGET")
    START_TIME=$(date +%s)

    echo -e "\n${BOLD}${GREEN}"
    echo "  ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗"
    echo "  ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║"
    echo "  ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║"
    echo "  ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║"
    echo "  ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║"
    echo "  ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝"
    echo -e "${RESET}"
    log_section "TARGET: $TARGET | $(date '+%Y-%m-%d %H:%M')"
    echo -e "  ${YELLOW}Nuclei:${RESET} -c ${NUCLEI_CONCURRENCY} / -rl ${NUCLEI_RATE} req/s  |  ${YELLOW}FFUF:${RESET} -t ${FFUF_THREADS} / -rate ${FFUF_RATE} req/s"
    echo ""

    BASE_DIR="$HOME/recopilacion/$TARGET"
    LOGSBASE="$BASE_DIR/$(date +'%Y_%m_%d-%H_%M')"
    LISTS_DIR="$HOME/recopilacion/lists"
    mkdir -p "$LOGSBASE/ffuf" "$LOGSBASE/puertos" "$LOGSBASE/gowitness_screens" "$LISTS_DIR"

    # FASE 0
    log_section "FASE 0: Verificación e instalación automática de dependencias"
    ALL_TOOLS=(shuffledns httpx nuclei katana subfinder dnsx gau unfurl gowitness subzy ffuf wafw00f whatweb masscan dig curl git python3 amass alterx testssl spoofcheck nmap theharvester cero)
    for tool in "${ALL_TOOLS[@]}"; do
        if command -v "$tool" &>/dev/null; then log_ok "$tool → OK"; else log_warn "$tool → Falta instalar en Dockerfile"; fi
    done
    log_ok "Fase 0 completada."

    # FASE 1
    log_section "FASE 1: Preparación del entorno"
    curl -sL "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt" -o "$LISTS_DIR/domains.txt" 2>/dev/null
    curl -sL "https://raw.githubusercontent.com/projectdiscovery/shuffledns/master/cmd/shuffledns/resolvers.txt" -o "$LISTS_DIR/resolvers.txt" 2>/dev/null
    curl -sL "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt" -o "$LISTS_DIR/dirb_common.txt" 2>/dev/null
    log_ok "Diccionarios y resolutores listos."

    # FASE 2
    log_section "FASE 2: Footprinting"
    run_with_spinner "ShuffleDNS (fuerza bruta DNS)" bash -c 'shuffledns -mode bruteforce -d "'"$TARGET"'" -w "'"$LISTS_DIR/domains.txt"'" -r "'"$LISTS_DIR/resolvers.txt"'" -t 150 -sw 10 -silent > "'"$LOGSBASE/shuffledns.txt"'" 2>/dev/null'
    run_with_spinner "Subfinder (OSINT pasivo)" bash -c 'subfinder -d "'"$TARGET"'" -silent -t 10 -o "'"$LOGSBASE/subfinder.txt"'" > /dev/null 2>&1'
    
    if [ ! -d "$LISTS_DIR/ctfr" ]; then git clone https://github.com/UnaPibaGeek/ctfr.git "$LISTS_DIR/ctfr" > /dev/null 2>&1 && pip3 install -r "$LISTS_DIR/ctfr/requirements.txt" --break-system-packages > /dev/null 2>&1; fi
    python3 "$LISTS_DIR/ctfr/ctfr.py" -d "$TARGET" -o "$LOGSBASE/ctfr.txt" > /dev/null 2>&1
    
    run_with_spinner "Cero (TLS Probing)" bash -c 'cero "'"$TARGET"'" 2>/dev/null | unfurl -u domains 2>/dev/null > "'"$LOGSBASE/cero.txt"'"'
    run_with_spinner "GAU (Wayback Machine)" bash -c 'gau --threads 5 --blacklist png,jpg,gif,css,woff,ttf,svg,ico,mp4,mp3 "'"$TARGET"'" 2>/dev/null | unfurl -u domains 2>/dev/null > "'"$LOGSBASE/gau.txt"'"'
    run_with_spinner "Katana (Web scraping JS)" bash -c 'echo "'"$TARGET"'" | katana -silent -jc -kf all -d 2 -c 20 2>/dev/null | unfurl -u domains 2>/dev/null > "'"$LOGSBASE/katana.txt"'"'
    run_with_spinner "AlterX + DnsX (Permutaciones)" bash -c 'sort -u "'"$LOGSBASE/shuffledns.txt"'" 2>/dev/null | head -100 | alterx -silent 2>/dev/null | dnsx -silent -r "'"$LISTS_DIR/resolvers.txt"'" > "'"$LOGSBASE/alterx.txt"'" 2>/dev/null'
    run_with_spinner "theHarvester (Buscando correos)" bash -c 'theharvester -d "'"$TARGET"'" -b google,bing,crtsh,otx -f "'"$LOGSBASE/theharvester"'" > /dev/null 2>&1'
    grep -oE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" "$LOGSBASE/theharvester.xml" 2>/dev/null | sort -u > "$LOGSBASE/emails.txt"

    timeout 300 amass enum -passive -d "$TARGET" -rf "$LISTS_DIR/resolvers.txt" -timeout 3 -o "$LOGSBASE/amass.txt" > /dev/null 2>&1
    
    cat "$LOGSBASE/shuffledns.txt" "$LOGSBASE/subfinder.txt" "$LOGSBASE/ctfr.txt" "$LOGSBASE/cero.txt" "$LOGSBASE/gau.txt" "$LOGSBASE/katana.txt" "$LOGSBASE/amass.txt" "$LOGSBASE/alterx.txt" 2>/dev/null | tr '[:upper:]' '[:lower:]' | grep -E "\.${TARGET_RE}$" | grep -vE "^\." | sort -u > "$LOGSBASE/subdominios_raw.txt"
    TOTAL_RAW=$(count_lines "$LOGSBASE/subdominios_raw.txt")
    log_ok "Total superficie de ataque teórica: $TOTAL_RAW endpoints"

    # FASE 3: EL CORAZÓN DEL SCRIPT RESTAURADO
    log_section "FASE 3: Fingerprinting (Analizando Vivos y Puertos)"
    
    log_info "[3a] HTTPX — Validando subdominios vivos..."
    run_with_spinner "HTTPX (Pinging web)" bash -c 'cat "'"$LOGSBASE/subdominios_raw.txt"'" | httpx -silent -status-code -title -tech-detect -follow-redirects -threads "'"$HTTPX_THREADS"'" -o "'"$LOGSBASE/httpx_full.txt"'" > /dev/null 2>&1'
    cat "$LOGSBASE/httpx_full.txt" 2>/dev/null | grep -v "\[301\]" | awk '{print $1}' | unfurl -u domains 2>/dev/null | sort -u > "$LOGSBASE/objetivos.txt"
    TOTAL_VIVOS=$(count_lines "$LOGSBASE/objetivos.txt")
    log_ok "HTTPX → $TOTAL_VIVOS subdominios vivos listos"

    log_info "[3b] WhatWeb — Extracción tecnológica..."
    run_with_spinner "WhatWeb (Identificando CMS/Frameworks)" bash -c 'whatweb -i "'"$LOGSBASE/objetivos.txt"'" --log-brief="'"$LOGSBASE/whatweb.txt"'" > /dev/null 2>&1'

    log_info "[3c] GoWitness — Capturas de pantalla..."
    run_with_spinner "GoWitness (Fotos de las webs)" bash -c 'gowitness file -f "'"$LOGSBASE/objetivos.txt"'" --screenshot-path "'"$LOGSBASE/gowitness_screens"'" --delay 2 --timeout 10 --threads 4 > /dev/null 2>&1'

    log_info "[3d] Wafw00f — Detección de WAF..."
    run_with_spinner "Wafw00f (Cloudflare, Akamai...)" bash -c 'wafw00f -i "'"$LOGSBASE/objetivos.txt"'" -o "'"$LOGSBASE/wafw00f.txt"'" > /dev/null 2>&1'

    log_info "[3e] FFUF — Fuzzing silencioso..."
    run_with_spinner "FFUF (Buscando directorios)" bash -c 'while IFS= read -r subdomain; do safe_name=$(echo "$subdomain" | tr "/: " "___"); ffuf -w "'"$LISTS_DIR/dirb_common.txt"'" -u "https://${subdomain}/FUZZ" -mc 200,401,403 -t "'"$FFUF_THREADS"'" -rate "'"$FFUF_RATE"'" -o "'"$LOGSBASE/ffuf/${safe_name}.json"'" -of json -s > /dev/null 2>&1; done < "'"$LOGSBASE/objetivos.txt"'"'

    log_info "[3f] Resolviendo IPs para escaneo de puertos..."
    > "$LOGSBASE/ips_unicas.txt"
    while IFS= read -r subdomain; do dig +short +retry=2 "$subdomain" 2>/dev/null | grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -n1 >> "$LOGSBASE/ips_unicas.txt"; done < "$LOGSBASE/objetivos.txt"
    sort -u "$LOGSBASE/ips_unicas.txt" -o "$LOGSBASE/ips_unicas.txt"

    log_info "[3g] Masscan + Nmap — Escaneo de puertos..."
    run_with_spinner "Masscan+Nmap (Buscando puertas abiertas)" bash -c 'while IFS= read -r ip; do safe_ip=$(echo "$ip" | tr "." "_"); mkdir -p "'"$LOGSBASE/puertos/$safe_ip"'"; masscan "$ip" -p21,22,25,53,80,110,143,443,445,993,995,3000,3306,3389,5432,8080,8443,8888,9090,9200 --max-rate "'"$MASSCAN_RATE"'" -oG "'"$LOGSBASE/puertos/$safe_ip/masscan.txt"'" > /dev/null 2>&1; open_ports=$(grep "^Host:" "'"$LOGSBASE/puertos/$safe_ip/masscan.txt"'" 2>/dev/null | grep -oE "Ports: [0-9]+" | grep -oE "[0-9]+" | tr "\n" "," | sed "s/,$//"); if [ -n "$open_ports" ]; then nmap -sS -Pn -sV -sC -T4 -p "$open_ports" "$ip" -oN "'"$LOGSBASE/puertos/$safe_ip/nmap.txt"'" > /dev/null 2>&1; fi; done < "'"$LOGSBASE/ips_unicas.txt"'"'

    # FASE 4
    log_section "FASE 4: Análisis de vulnerabilidades"
    
    log_info "[4a] Subzy — Subdomain Takeover..."
    run_with_spinner "Subzy" bash -c 'subzy run --targets "'"$LOGSBASE/objetivos.txt"'" > "'"$LOGSBASE/subzy_takeovers.txt"'" 2>/dev/null'
    
    log_info "[4b] TestSSL — Fallos criptográficos..."
    run_with_spinner "TestSSL" bash -c 'head -10 "'"$LOGSBASE/objetivos.txt"'" | while IFS= read -r host; do testssl --quiet --color 0 -U "https://$host" >> "'"$LOGSBASE/testssl.txt"'" 2>/dev/null; done'

    log_info "[4c] Nuclei — Escáner de seguridad..."
    run_with_spinner "Nuclei (CVEs y Plantillas)" bash -c 'nuclei -l "'"$LOGSBASE/objetivos.txt"'" -s critical,high,medium -c "'"$NUCLEI_CONCURRENCY"'" -rl "'"$NUCLEI_RATE"'" -etags dos -silent -o "'"$LOGSBASE/nuclei_vulns.txt"'" > /dev/null 2>&1'
    NUCLEI_CRITICAL=$(grep -ic "\[critical\]" "$LOGSBASE/nuclei_vulns.txt" 2>/dev/null || echo "0")
    NUCLEI_HIGH=$(grep -ic "\[high\]" "$LOGSBASE/nuclei_vulns.txt" 2>/dev/null || echo "0")
    log_ok "Nuclei → ${RED}$NUCLEI_CRITICAL critical${RESET} / ${YELLOW}$NUCLEI_HIGH high${RESET}"

    log_info "[4d] DMARC y SPF..."
    run_with_spinner "Spoofcheck" bash -c 'spoofcheck "'"$TARGET"'" > "'"$LOGSBASE/dmarc_spf.txt"'" 2>/dev/null'

    # FASE 5
    log_section "FASE 5: Generando resumen ejecutivo"
    END_TIME=$(date +%s)
    ELAPSED=$(( (END_TIME - START_TIME) / 60 ))
    REPORTE="$LOGSBASE/$TARGET-resumen-final.txt"

    cat > "$REPORTE" <<ENDREPORT
=================================================================
  RESUMEN EJECUTIVO DE RECONOCIMIENTO — $TARGET
  Duración: ${ELAPSED}m
=================================================================
### 1. PERÍMETRO ###
  Subdominios vivos (HTTP/HTTPS): $TOTAL_VIVOS
  IPs únicas: $(count_lines "$LOGSBASE/ips_unicas.txt")
  Emails encontrados: $(count_lines "$LOGSBASE/emails.txt")

### 2. VULNERABILIDADES (Nuclei) ###
$(grep -E "critical|high" "$LOGSBASE/nuclei_vulns.txt" 2>/dev/null || echo "  Ninguna crítica/alta.")

### 3. TAKEOVERS ###
$(grep -i "vulnerable" "$LOGSBASE/subzy_takeovers.txt" 2>/dev/null || echo "  Ninguno detectado.")
=================================================================
ENDREPORT

    log_ok "Pipeline completado en ${ELAPSED}m"
    echo -e "  📡 Vivos: $TOTAL_VIVOS | 🔴 Críticos: $NUCLEI_CRITICAL | 📧 Emails: $(count_lines "$LOGSBASE/emails.txt")"
    echo -e "  📁 Resultados crudos: $LOGSBASE"
}

case "$1" in
    *) recon "$1" ;;
esac
