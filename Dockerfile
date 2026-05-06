FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# 1. Instalar dependencias base del sistema
RUN apt-get update && apt-get install -y \
    python3 python3-pip git curl wget sudo \
    nmap masscan dnsutils whois libpcap-dev whatweb \
    && rm -rf /var/lib/apt/lists/*

# 2. Instalar Golang
RUN wget https://go.dev/dl/go1.21.6.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz && \
    rm go1.21.6.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin:/root/go/bin

# 3. Instalar CERO (El ninja de los certificados SSL)
RUN go install github.com/glebarez/cero@latest

# 4. Instalar theHarvester (En Ubuntu 24.04 con Python 3.12+)
RUN git clone https://github.com/laramies/theHarvester.git /opt/theHarvester && \
    cd /opt/theHarvester && \
    pip3 install . --break-system-packages && \
    printf '#!/bin/bash\npython3 /opt/theHarvester/theHarvester.py "$@"\n' > /usr/bin/theharvester && \
    chmod +x /usr/bin/theharvester

# 5. Instalar Streamlit y wafw00f
RUN pip3 install streamlit wafw00f --break-system-packages

WORKDIR /app

# 6. Copiar tus archivos al contenedor
COPY recon2.sh .
COPY app.py .
RUN chmod +x recon2.sh

EXPOSE 8501

# 7. Lanzar la web
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
