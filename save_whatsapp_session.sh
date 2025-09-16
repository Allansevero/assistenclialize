#!/bin/bash

echo "--- Implementando a Persistência da Sessão WhatsApp no Banco de Dados ---"
echo ""

# Navega para a pasta do backend
cd api

# --- Passo 1: Atualizar o whatsapp.service.ts ---
echo "[1/1] Atualizando o arquivo src/features/whatsapp/whatsapp.service.ts com a lógica de salvamento..."

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

  public async createSession(userId: string) {
    console.log(`[SessionManager] Criando nova sessão para o usuário: ${userId}`);
    
    // --- LÓGICA DE BANCO DE DADOS (INÍCIO) ---
    // Cria um registro no banco para esta nova sessão antes de tudo
    const newDbSession = await prisma.whatsappSession.create({
      data: {
        name: `Sessão de ${userId.substring(0, 8)}`, // Nome provisório
        status: "INITIALIZING",
        assignedToId: userId,
      }
    });
    const sessionId = newDbSession.id; // Usaremos o ID do DB como nosso ID de sessão
    console.log(`[${sessionId}] Registro da sessão criado no banco de dados.`);
    // --- LÓGICA DE BANCO DE DADOS (FIM) ---
    
    const client = new Client({
      authStrategy: new LocalAuth({ clientId: sessionId }), // Usa o ID do DB
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
      // --- LÓGICA DE BANCO DE DADOS (INÍCIO) ---
      // Atualiza o status no banco para indicar que está conectado
      await prisma.whatsappSession.update({
        where: { id: sessionId },
        data: { status: 'CONNECTED' },
      });
      // --- LÓGICA DE BANCO DE DADOS (FIM) ---
      this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!' });
    });
    
    // --- O MOMENTO MAIS IMPORTANTE! ---
    client.on('authenticated', async (session) => {
      console.log(`[${sessionId}] Autenticado! Salvando dados da sessão no banco...`);
      // --- LÓGICA DE BANCO DE DADOS (INÍCIO) ---
      await prisma.whatsappSession.update({
        where: { id: sessionId },
        data: { 
          // O objeto 'session' é salvo diretamente no campo do tipo Json
          sessionData: session as any,
        },
      });
      console.log(`[${sessionId}] Dados da sessão salvos com sucesso!`);
      // --- LÓGICA DE BANCO DE DADOS (FIM) ---
    });

    client.on('auth_failure', (msg) => {
      console.error(`[${sessionId}] Falha na autenticação:`, msg);
      this.io?.to(userId).emit('auth-failure', { message: 'Falha na autenticação.' });
    });

    client.on('disconnected', async (reason) => {
      console.log(`[${sessionId}] Cliente foi desconectado:`, reason);
      // --- LÓGICA DE BANCO DE DADOS (INÍCIO) ---
      await prisma.whatsappSession.update({
        where: { id: sessionId },
        data: { status: 'DISCONNECTED', sessionData: null },
      });
      // --- LÓGICA DE BANCO DE DADOS (FIM) ---
      this.clients.delete(sessionId);
    });

    client.initialize();
    this.clients.set(sessionId, client);
  }
}

export const sessionManager = SessionManager.getInstance();
EOF

echo "  -> whatsapp.service.ts (Atualizado com a lógica de persistência!)"
echo ""

echo "--- SUCESSO! O backend agora irá salvar as sessões no banco de dados. ---"