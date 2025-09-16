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
  
  public async getChats(sessionId: string) {
    const client = this.clients.get(sessionId);
    if (!client || (await client.getState()) !== 'CONNECTED') { // Checagem de status mais robusta
      throw new Error('Sessão não encontrada ou não está pronta.');
    }
    const chats = await client.getChats();
    return chats.map(chat => ({ id: chat.id._serialized, name: chat.name, isGroup: chat.isGroup }));
  }

  public async getMessages(sessionId: string, chatId: string) {
    const client = this.clients.get(sessionId);
    if (!client || (await client.getState()) !== 'CONNECTED') { throw new Error('Sessão não encontrada ou não está pronta.'); }
    const chat = await client.getChatById(chatId);
    const messages = await chat.fetchMessages({ limit: 50 });
    return messages;
  }

  public async listSessions(userId: string) {
    return prisma.whatsappSession.findMany({ where: { assignedToId: userId }, select: { id: true, name: true, status: true } });
  }

  public async initializeFromDb() {
    console.log('[DEBUG] Procurando por sessões com status CONNECTED...');
    const savedSessions = await prisma.whatsappSession.findMany({ where: { status: 'CONNECTED' } });

    console.log(`[SessionManager] ${savedSessions.length} sessões encontradas para recarregar.`);
    if (savedSessions.length > 0) {
      console.log('[DEBUG] Detalhes das sessões encontradas:', savedSessions.map(s => ({ id: s.id, name: s.name, status: s.status })));
    }

    for (const session of savedSessions) {
      if (session.sessionData) {
        this.restoreSession(session.id, session.assignedToId!);
      } else {
        console.log(`[WARN] Sessão ${session.id} marcada como CONNECTED mas sem sessionData. Pulando...`);
      }
    }
  }

  private restoreSession(sessionId: string, userId: string) {
    console.log(`[${sessionId}] Restaurando sessão...`);
    const client = new Client({ authStrategy: new LocalAuth({ clientId: sessionId }), puppeteer: { headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] } });
    
    // Adiciona o cliente ao mapa imediatamente para que ele possa ser encontrado
    this.clients.set(sessionId, client);
    
    client.on('ready', async () => {
      console.log(`[${sessionId}] SESSÃO RESTAURADA E PRONTA!`); // Log de sucesso claro
      this.io?.to(userId).emit('session-restored', { message: `Sessão ${sessionId} restaurada com sucesso!` });
    });
    
    client.on('disconnected', async (reason) => { 
      console.log(`[${sessionId}] Cliente (restaurado) foi desconectado:`, reason); 
      await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED' } }); 
      this.clients.delete(sessionId); 
    });

    client.initialize().catch(err => console.error(`[${sessionId}] Falha ao inicializar cliente restaurado:`, err));
  }

  public async createSession(userId: string) {
    console.log(`[SessionManager] Criando nova sessão para o usuário: ${userId}`);
    const newDbSession = await prisma.whatsappSession.create({ data: { name: `Sessão de ${userId.substring(0, 8)}`, status: "INITIALIZING", assignedToId: userId } });
    const sessionId = newDbSession.id;
    const client = new Client({ authStrategy: new LocalAuth({ clientId: sessionId }), puppeteer: { headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] } });
    
    // Adiciona o cliente ao mapa imediatamente
    this.clients.set(sessionId, client);

    client.on('qr', (qr) => { console.log(`[${sessionId}] QR Code recebido...`); this.io?.to(userId).emit('qr-code', qr); });
    
    client.on('authenticated', async (session) => {
      console.log(`[${sessionId}] Autenticado! Salvando dados da sessão no banco...`);
      const updated = await prisma.whatsappSession.update({ where: { id: sessionId }, data: { sessionData: session as any }});
      console.log('[DEBUG] sessionData salvo com sucesso. ID:', updated.id);
    });

    client.on('ready', async () => {
      console.log(`[${sessionId}] CLIENTE PRONTO! Atualizando status para CONNECTED...`);
      const updated = await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'CONNECTED' } });
      console.log('[DEBUG] Status da sessão atualizado para:', updated.status);
      this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!' });
    });
    
    client.on('disconnected', async (reason) => { 
      console.log(`[${sessionId}] Cliente (novo) foi desconectado:`, reason); 
      await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED' } }); 
      this.clients.delete(sessionId); 
    });

    client.initialize().catch(err => console.error(`[${sessionId}] Falha ao inicializar novo cliente:`, err));
  }
}
export const sessionManager = SessionManager.getInstance();
EOF

echo "  -> whatsapp.service.ts (Atualizado com logs de depuração!)"
echo ""
echo "--- SUCESSO! O backend agora possui logs detalhados. ---"