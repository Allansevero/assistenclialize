#!/bin/bash

echo "--- Iniciando a Preparação do Banco de Dados para as Sessões WhatsApp ---"
echo ""

# Navega para a pasta do backend
cd api

# --- Passo 1: Atualizar o schema.prisma ---
echo "[1/2] Atualizando o arquivo prisma/schema.prisma com o modelo WhatsappSession..."

cat << 'EOF' > prisma/schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

model User {
  id        String    @id @default(cuid())
  email     String    @unique
  name      String
  password  String
  role      UserRole  @default(MEMBER)
  teamId    String?
  team      Team?     @relation(fields: [teamId], references: [id])
  sessions  WhatsappSession[]
}

model Team {
  id      String   @id @default(cuid())
  name    String
  ownerId String   @unique
  members User[]
}

// --- MODELO WhatsappSession ATUALIZADO E COMPLETO ---
model WhatsappSession {
  id            String    @id @default(cuid())
  name          String?   // Nome customizado, ex: "WhatsApp Vendas 1"
  status        String    @default("DISCONNECTED") // Ex: CONNECTED, DISCONNECTED
  
  // O campo mais importante: onde guardamos a chave mestra da sessão.
  // O tipo Json é específico para bancos como o PostgreSQL.
  sessionData   Json?
  
  // Relação com o usuário que está designado para esta sessão
  assignedToId  String?
  assignedTo    User?     @relation(fields: [assignedToId], references: [id])
}

enum UserRole {
  ADMIN
  MEMBER
}
EOF

echo "  -> prisma/schema.prisma (Atualizado com sucesso!)"
echo ""

# --- Passo 2: Aplicar a migração ao banco de dados ---
echo "[2/2] Executando a migração do banco de dados para criar a nova tabela..."
npx prisma migrate dev --name add-whatsapp-session

echo ""
echo "--- SUCESSO! O banco de dados está pronto para armazenar as sessões do WhatsApp. ---"