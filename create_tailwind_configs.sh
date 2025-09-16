#!/bin/bash

echo "--- CRIANDO ARQUIVOS DE CONFIGURAÇÃO DO TAILWIND MANUALMENTE ---"
echo "Contornando o erro do npx..."
echo ""

# Navega para a pasta do frontend
cd src

# Cria o postcss.config.js
cat << 'EOF' > postcss.config.js
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF
echo "  -> 'postcss.config.js' criado com sucesso."

# O tailwind.config.js já foi criado no passo anterior, vamos apenas garantir o conteúdo
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
echo "  -> 'tailwind.config.js' configurado com sucesso."
echo ""

cd ..
echo "--- ✅ SUCESSO! Arquivos de configuração criados. ---"
echo "Agora, por favor, continue do passo 4 da nossa lista anterior para finalizar a Etapa 1."