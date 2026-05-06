import streamlit as st
import subprocess
import os

# Configuración de la página
st.set_page_config(page_title="Recon Dashboard", page_icon="🎯", layout="wide")
st.title("🛡️ Recon Dashboard v1.0")
st.markdown("Panel de control para Bug Bounty y Red Teaming automatizado.")

# ==========================================
# BARRA LATERAL: Historial de Escaneos
# ==========================================
st.sidebar.header("📁 Historial de Targets")
base_dir = "/root/recopilacion"

if os.path.exists(base_dir):
    # Buscar carpetas de targets (omitiendo la carpeta 'lists')
    targets = [d for d in os.listdir(base_dir) if os.path.isdir(os.path.join(base_dir, d)) and d != "lists"]
    selected_target = st.sidebar.selectbox("Selecciona un Target", ["Ninguno"] + targets)
    
    if selected_target != "Ninguno":
        target_dir = os.path.join(base_dir, selected_target)
        scans = sorted(os.listdir(target_dir), reverse=True)
        selected_scan = st.sidebar.selectbox("Selecciona un Escaneo", scans)
        
        report_path = os.path.join(target_dir, selected_scan, f"{selected_target}-resumen-final.txt")
        if st.sidebar.button("Ver Resumen Ejecutivo"):
            if os.path.exists(report_path):
                with open(report_path, "r") as f:
                    st.sidebar.text_area("Reporte:", f.read(), height=400)
            else:
                st.sidebar.warning("El escaneo aún no ha terminado o no generó reporte.")

# ==========================================
# PANEL CENTRAL: Lanzador
# ==========================================
st.write("---")
target = st.text_input("🎯 Introduce el dominio a escanear (ej. ups.com):")

if st.button("🚀 Lanzar Pipeline"):
    if target:
        st.info(f"Iniciando escaneo para: {target}... (No cierres esta pestaña)")
        
        # Aquí creamos la "caja negra" que simula la terminal
        terminal_output = st.empty()
        output_text = ""
        
        # Ejecutamos tu script recon2.sh
        process = subprocess.Popen(
            ["./recon2.sh", target],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            universal_newlines=True
        )
        
        # Bucle para leer la terminal en directo e inyectarla en la web
        for line in process.stdout:
            output_text += line
            terminal_output.code(output_text, language="bash")
            
        process.wait()
        
        if process.returncode == 0:
            st.success("✅ ¡Escaneo completado con éxito! Revisa la barra lateral.")
        else:
            st.error("❌ El escaneo abortó o terminó con errores.")
    else:
        st.warning("Por favor, introduce un dominio válido.")
