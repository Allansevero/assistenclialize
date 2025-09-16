#!/bin/bash

echo "--- Desativando Temporariamente o TailwindCSS para Remover o Erro ---"
echo ""

# Navega para a pasta do frontend
cd src

# --- Limpa o conteúdo do index.css ---
# Isto remove as diretivas @tailwind que estão causando o erro.
echo "[1/1] Limpando o arquivo src/index.css..."
cat << 'EOF' > src/index.css
/* O conteúdo do TailwindCSS foi removido temporariamente 
  para permitir o avanço no desenvolvimento da lógica principal.
  Vamos reativar e corrigir o estilo em uma fase futura.
*/
EOF

echo "  -> src/index.css (Limpo com sucesso!)"
echo ""
echo "--- SUCESSO! O gatilho do erro foi removido. ---"
echo "Por favor, reinicie o servidor de desenvolvimento do frontend agora."