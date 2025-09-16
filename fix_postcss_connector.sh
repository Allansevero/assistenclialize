#!/bin/bash

echo "--- Instalando o Conector @tailwindcss/postcss ---"
echo ""

# Navega para a pasta do frontend
cd src

# --- Instala o pacote que o erro nos pediu ---
echo "[1/1] Instalando @tailwindcss/postcss..."
npm install @tailwindcss/postcss

echo ""
echo "--- SUCESSO! Pacote conector instalado. ---"
echo "Agora, por favor, REINICIE o servidor de desenvolvimento."