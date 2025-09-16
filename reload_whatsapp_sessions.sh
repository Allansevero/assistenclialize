#!/bin/bash

echo "--- Implementando a Recarga Automática de Sessões na Inicialização ---"
echo ""

# Navega para a pasta do backend
cd api

# --- Passo 1: Atualizar o whatsapp.service.ts ---
echo "[1/2] Atualizando o whatsapp.service.ts com a lógica de recarregamento..."

cat << 'EOF' > src/features/whatsapp/whatsapp.service.ts
import { Client, LocalAuth } from 'whatsapp-web.js';
import { Server as SocketIOServer } from 'socket.io';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

class SessionManager {
  private static instance: SessionManager;
  public io: SocketIOServer | null = null;
  private clients: Map<string, Client> = new Map();

  private constructor() {}

  public static getInstance(): SessionManager {
    if (!SessionManager.instance) {
      SessionManager.instance = new SessionManager();
    }
    return SessionManager.instance;
  }

  // --- NOVA FUNÇÃO PARA RECARREGAR SESSÕES DO DB ---
  public async initializeFromDb() {
    console.log('[SessionManager] Verificando sessões salvas no banco de dados...');
    const savedSessions = await prisma.whatsappSession.findMany({
      where: { status: 'CONNECTED', sessionData: { not: null } },
    });

    console.log(`[SessionManager] ${savedSessions.length} sessões encontradas para recarregar.`);

    for (const session of savedSessions) {
      this.restoreSession(session.id, session.assignedToId!);
    }
  }

  private restoreSession(sessionId: string, userId: string) {
    console.log(`[${sessionId}] Restaurando sessão...`);
    
    // A mágica acontece aqui: a LocalAuth irá procurar os dados da sessão
    // que foram salvos na pasta .wwebjs_auth/session-<sessionId>
    const client = new Client({
      authStrategy: new LocalAuth({ clientId: sessionId }),
      puppeteer: {
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      }
    });

    client.on('ready', async () => {
      console.log(`[${sessionId}] Sessão restaurada e pronta!`);
      this.io?.to(userId).emit('session-restored', { message: `Sessão ${sessionId} restaurada com sucesso!` });
    });

    client.on('auth_failure', (msg) => {
      console.error(`[${sessionId}] Falha na autenticação ao restaurar:`, msg);
    });

    client.on('disconnected', async (reason) => {
      console.log(`[${sessionId}] Cliente (restaurado) foi desconectado:`, reason);
      await prisma.whatsappSession.update({
        where: { id: sessionId },
        data: { status: 'DISCONNECTED', sessionData: null },
      });
      this.clients.delete(sessionId);
    });

    client.initialize();
    this.clients.set(sessionId, client);
  }


  public async createSession(userId: string) {
    console.log(`[SessionManager] Criando nova sessão para o usuário: ${userId}`);
    const newDbSession = await prisma.whatsappSession.create({
      data: {
        name: `Sessão de ${userId.substring(0, 8)}`,
        status: "INITIALIZING",
        assignedToId: userId,
      }
    });
    const sessionId = newDbSession.id;
    console.log(`[${sessionId}] Registro da sessão criado no banco de dados.`);
    
    const client = new Client({
      authStrategy: new LocalAuth({ clientId: sessionId }),
      puppeteer: {
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      }
    });

    client.on('qr', (qr) => {
      console.log(`[${sessionId}] QR Code recebido. Enviando para o frontend...`);
      this.io?.to(userId).emit('qr-code', qr);
    });

    client.on('ready', async () => {
      console.log(`[${sessionId}] Cliente está pronto!`);
      await prisma.whatsappSession.update({
        where: { id: sessionId },
        data: { status: 'CONNECTED' },
      });
      this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!' });
    });
    
    client.on('authenticated', async (session) => {
      console.log(`[${sessionId}] Autenticado! Salvando dados da sessão no banco...`);
      await prisma.whatsappSession.update({
        where: { id: sessionId },
        data: { sessionData: session as any },
      });
      console.log(`[${sessionId}] Dados da sessão salvos com sucesso!`);
    });

    client.on('auth_failure', (msg) => {
      console.error(`[${sessionId}] Falha na autenticação:`, msg);
      this.io?.to(userId).emit('auth-failure', { message: 'Falha na autenticação.' });
    });

    client.on('disconnected', async (reason) => {
      console.log(`[${sessionId}] Cliente foi desconectado:`, reason);
      await prisma.whatsappSession.update({
        where: { id: sessionId },
        data: { status: 'DISCONNECTED', sessionData: null },
      });
      this.clients.delete(sessionId);
    });

    client.initialize();
    this.clients.set(sessionId, client);
  }
}

export const sessionManager = SessionManager.getInstance();
EOF

echo "  -> whatsapp.service.ts (Atualizado com a lógica de recarregamento!)"
echo ""

# --- Passo 2: Atualizar o server.ts para chamar a nova função ---
echo "[2/2] Atualizando o arquivo src/server.ts para iniciar a recarga..."

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

const io = new SocketIOServer(server, {
  cors: {
    origin: "http://localhost:5173",
    methods: ["GET", "POST"]
  }
});

sessionManager.io = io;

const PORT = process.env.PORT || 3000;

app.use(cors({ origin: 'http://localhost:5173' }));
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

server.listen(PORT, () => {
  console.log(`🚀 Servidor rodando em http://localhost:${PORT}`);
  // --- INICIA A RECARGA DE SESSÕES QUANDO O SERVIDOR FICA PRONTO ---
  sessionManager.initializeFromDb();
});
EOF

echo "  -> src/server.ts (Atualizado para chamar a recarga!)"
echo ""

echo "--- SUCESSO! O backend agora irá recarregar as sessões salvas na inicialização. ---"