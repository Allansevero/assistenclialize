#!/bin/bash

echo "--- Adicionando Logs Detalhados para Depuração do Serviço WhatsApp ---"
echo ""

# Navega para a pasta do backend
cd api

# --- Atualiza o whatsapp.service.ts com mais logs ---
echo "[1/1] Atualizando o arquivo src/features/whatsapp/whatsapp.service.ts..."

cat << 'EOF' > src/features/whatsapp/whatsapp.service.ts
import { Client, LocalAuth, Message } from 'whatsapp-web.js';
import { Server as SocketIOServer } from 'socket.io';
import { Prisma, PrismaClient } from '@prisma/client';

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

  public async initializeFromDb() {
    console.log('[DEBUG] Procurando por sessões com status CONNECTED...');
    const savedSessions = await prisma.whatsappSession.findMany({
      where: { status: 'CONNECTED' },
    });

    console.log(`[SessionManager] ${savedSessions.length} sessões encontradas para recarregar.`);
    if (savedSessions.length > 0) {
      console.log('[DEBUG] Sessões encontradas:', savedSessions.map(s => ({ id: s.id, name: s.name, status: s.status })));
    }


    for (const session of savedSessions) {
      if (session.sessionData) {
        this.restoreSession(session.id, session.assignedToId!);
      }
    }
  }

  private restoreSession(sessionId: string, userId: string) {
    console.log(`[${sessionId}] Restaurando sessão...`);
    
    const client = new Client({
      authStrategy: new LocalAuth({ clientId: sessionId }),
      puppeteer: { headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] }
    });

    client.on('ready', async () => {
      console.log(`[${sessionId}] Sessão restaurada e pronta!`);
      this.io?.to(userId).emit('session-restored', { message: `Sessão ${sessionId} restaurada com sucesso!` });
    });

    client.on('auth_failure', (msg) => console.error(`[${sessionId}] Falha na autenticação ao restaurar:`, msg));

    client.on('disconnected', async (reason) => {
      console.log(`[${sessionId}] Cliente (restaurado) foi desconectado:`, reason);
      await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED' } });
      this.clients.delete(sessionId);
    });

    client.on('message', (msg: Message) => {
      console.log(`[${sessionId}] Nova mensagem recebida de ${msg.from}: ${msg.body}`);
      // Futuramente, emitiremos via socket para o frontend
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
      puppeteer: { headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] }
    });

    client.on('qr', (qr) => {
      console.log(`[${sessionId}] QR Code recebido. Enviando para o frontend...`);
      this.io?.to(userId).emit('qr-code', qr);
    });

    client.on('authenticated', async (session) => {
      console.log(`[${sessionId}] Autenticado! Salvando dados da sessão no banco...`);
      const updatedSession = await prisma.whatsappSession.update({
        where: { id: sessionId },
        data: { sessionData: session as any },
      });
      console.log('[DEBUG] Dados da sessão salvos. sessionData está preenchido? ', !!updatedSession.sessionData);
    });

    client.on('ready', async () => {
      console.log(`[${sessionId}] Cliente está pronto! Atualizando status para CONNECTED...`);
      const updatedSession = await prisma.whatsappSession.update({
        where: { id: sessionId },
        data: { status: 'CONNECTED' },
      });
      console.log('[DEBUG] Status da sessão atualizado. Novo status:', updatedSession.status);
      this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!' });
    });
    
    client.on('disconnected', async (reason) => {
      console.log(`[${sessionId}] Cliente foi desconectado:`, reason);
      await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED' } });
      this.clients.delete(sessionId);
    });

    client.initialize();
    this.clients.set(sessionId, client);
  }
}

export const sessionManager = SessionManager.getInstance();
EOF

echo "  -> whatsapp.service.ts (Atualizado com logs de depuração!)"
echo ""
echo "--- SUCESSO! O backend agora possui logs detalhados. ---"