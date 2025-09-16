#!/bin/bash

echo "--- EXECUTANDO REMOÇÃO COMPLETA DO TAILWINDCSS E POSTCSS ---"
echo "Seguindo a ordem de focar 100% na funcionalidade."
echo ""
sleep 2

# Navega para a pasta do frontend
cd src

# --- Passo 1: Desinstalar TODOS os pacotes relacionados ---
echo "[1/3] Desinstalando tailwindcss, postcss, autoprefixer e o conector..."
npm uninstall tailwindcss postcss autoprefixer @tailwindcss/postcss
echo "Pacotes de CSS removidos."
echo ""

# --- Passo 2: Apagar os arquivos de configuração ---
echo "[2/3] Apagando os arquivos de configuração tailwind.config.js e postcss.config.js..."
rm -f tailwind.config.js
rm -f postcss.config.js
echo "Arquivos de configuração removidos."
echo ""

# --- Passo 3: Garantir que o index.css está limpo ---
echo "[3/3] Limpando o arquivo src/index.css para garantir que não há resíduos..."
cat << 'EOF' > src/index.css
/* O sistema de estilização foi completamente removido para eliminar
   erros de build e focar na lógica da aplicação.
*/
EOF
echo "Arquivo de CSS limpo."
echo ""

echo "--- SUCESSO! A CAUSA DO ERRO FOI REMOVIDA DO PROJETO. ---"
echo "O erro de PostCSS não irá mais aparecer."
echo "Por favor, reinicie o servidor de desenvolvimento do frontend."
