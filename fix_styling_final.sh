#!/bin/bash

echo "--- Iniciando a Criação Manual dos Arquivos de Configuração do TailwindCSS ---"
echo ""

# Navega para a pasta do frontend
cd src

# --- Passo 1: Criar o postcss.config.js ---
echo "[1/2] Criando o arquivo postcss.config.js..."
cat << 'EOF' > postcss.config.js
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF
echo "  -> postcss.config.js (Criado com sucesso!)"
echo ""

# --- Passo 2: Criar o tailwind.config.js ---
echo "[2/2] Criando o arquivo tailwind.config.js..."
cat << 'EOF' > tailwind.config.js
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF
echo "  -> tailwind.config.js (Criado com sucesso!)"
echo ""

echo "--- SUCESSO! Os arquivos de configuração que faltavam foram criados. ---"
echo "Por favor, reinicie o servidor de desenvolvimento do frontend agora."