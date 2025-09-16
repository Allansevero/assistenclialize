#!/bin/bash

echo "--- Atualizando a Política de CORS para Permitir Acesso da Rede Local ---"
echo ""

# Navega para a pasta do backend
cd api

# --- Atualiza o server.ts com uma política de CORS mais flexível ---
echo "[1/1] Atualizando o arquivo src/server.ts..."

cat << 'EOF' > src/server.ts
import express from 'express';
import cors from 'cors';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';

import authRoutes from './features/auth/auth.routes';
import teamRoutes from './features/teams/teams.routes';
import whatsappRoutes from './features/whatsapp/whatsapp.routes';
import { sessionManager } from './features/whatsapp/whatsapp.service';

const app = express();
const server = http.createServer(app);

// --- POLÍTICA DE CORS ATUALIZADA ---
// Permite múltiplos endereços de origem
const allowedOrigins = [
    'http://localhost:5173', // Para desenvolvimento local
    // O Vite em modo de rede pode usar outros endereços, então adicionamos um coringa
];

const corsOptions = {
  // A origem pode ser uma função para maior flexibilidade
  origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    // Para testes de rede, vamos ser mais permissivos.
    // Em produção, isso deve ser uma lista restrita!
    console.log('CORS check for origin:', origin);
    callback(null, true);
  },
};

const io = new SocketIOServer(server, { cors: corsOptions });

sessionManager.io = io;

const PORT = process.env.PORT || 3000;

app.use(cors(corsOptions)); // Usa as novas opções de CORS
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/teams', teamRoutes);
app.use('/api/whatsapp', whatsappRoutes);

io.on('connection', (socket) => {
  console.log(`[Socket.IO] Novo cliente conectado: ${socket.id}`);
  socket.on('join-room', (userId) => {
    console.log(`[Socket.IO] Cliente ${socket.id} entrou na sala ${userId}`);
    socket.join(userId);
  });
  socket.on('disconnect', () => {
    console.log(`[Socket.IO] Cliente desconectado: ${socket.id}`);
  });
});

server.listen(PORT, '0.0.0.0', () => { // Escuta em todas as interfaces de rede
  console.log(`🚀 Servidor rodando em http://localhost:${PORT} e acessível na rede local`);
  sessionManager.initializeFromDb();
});
EOF

echo "  -> src/server.ts (Atualizado com CORS flexível e acesso via rede)"
echo ""
echo "--- SUCESSO! O backend está pronto para a prova de fogo. ---"