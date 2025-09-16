#!/bin/bash

echo "--- Corrigindo a Lógica de Salvamento da Sessão para ser Atômica ---"
cd api

cat << 'EOF' > src/features/whatsapp/whatsapp.service.ts
import { Client, LocalAuth, Message } from 'whatsapp-web.js';
import { Server as SocketIOServer } from 'socket.io';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

class SessionManager {
  private static instance: SessionManager;
  public io: SocketIOServer | null = null;
  private clients: Map<string, Client> = new Map();

  // ... (código existente sem alterações) ...
  private constructor() {}
  public static getInstance(): SessionManager { if (!SessionManager.instance) { SessionManager.instance = new SessionManager(); } return SessionManager.instance; }
  public async getChats(sessionId: string) { const client = this.clients.get(sessionId); if (!client || (await client.getState()) !== 'CONNECTED') { throw new Error('Sessão não encontrada ou não está pronta.'); } const chats = await client.getChats(); return chats.map(chat => ({ id: chat.id._serialized, name: chat.name, isGroup: chat.isGroup })); }
  public async getMessages(sessionId: string, chatId: string) { const client = this.clients.get(sessionId); if (!client || (await client.getState()) !== 'CONNECTED') { throw new Error('Sessão não encontrada ou não está pronta.'); } const chat = await client.getChatById(chatId); const messages = await chat.fetchMessages({ limit: 50 }); return messages; }
  public async listSessions(userId: string) { return prisma.whatsappSession.findMany({ where: { assignedToId: userId }, select: { id: true, name: true, status: true } }); }
  
  public async initializeFromDb() {
    console.log('[DEBUG] Procurando por sessões com status CONNECTED...');
    const savedSessions = await prisma.whatsappSession.findMany({ where: { status: 'CONNECTED' } });
    console.log(`[SessionManager] ${savedSessions.length} sessões encontradas para recarregar.`);
    if (savedSessions.length > 0) { console.log('[DEBUG] Detalhes:', savedSessions.map(s => ({ id: s.id, name: s.name, status: s.status }))); }
    for (const session of savedSessions) {
      if (session.sessionData) {
        this.restoreSession(session.id, session.assignedToId!);
      } else {
        console.log(`[WARN] Sessão ${session.id} marcada como CONNECTED mas sem sessionData. Pulando...`);
      }
    }
  }

  private restoreSession(sessionId: string, userId: string) { /* ... (código existente sem alterações) ... */ console.log(`[${sessionId}] Restaurando sessão...`); const client = new Client({ authStrategy: new LocalAuth({ clientId: sessionId }), puppeteer: { headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] } }); this.clients.set(sessionId, client); client.on('ready', async () => { console.log(`[${sessionId}] SESSÃO RESTAURADA E PRONTA!`); this.io?.to(userId).emit('session-restored', { message: `Sessão ${sessionId} restaurada com sucesso!` }); }); client.on('disconnected', async (reason) => { console.log(`[${sessionId}] Cliente (restaurado) foi desconectado:`, reason); await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED' } }); this.clients.delete(sessionId); }); client.initialize().catch(err => console.error(`[${sessionId}] Falha ao inicializar cliente restaurado:`, err)); }

  public async createSession(userId: string) {
    console.log(`[SessionManager] Criando nova sessão para o usuário: ${userId}`);
    const newDbSession = await prisma.whatsappSession.create({ data: { name: `Sessão de ${userId.substring(0, 8)}`, status: "INITIALIZING", assignedToId: userId } });
    const sessionId = newDbSession.id;
    const client = new Client({ authStrategy: new LocalAuth({ clientId: sessionId }), puppeteer: { headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] } });
    this.clients.set(sessionId, client);

    client.on('qr', (qr) => { this.io?.to(userId).emit('qr-code', qr); });
    
    // --- LÓGICA CORRIGIDA ---
    client.on('authenticated', async (session) => {
      console.log(`[${sessionId}] Autenticado! Salvando dados e marcando como CONECTADO...`);
      const updated = await prisma.whatsappSession.update({
        where: { id: sessionId },
        // Operação Atômica: Salva os dados E o status de uma só vez
        data: { 
          sessionData: session as any,
          status: 'CONNECTED' 
        },
      });
      console.log('[DEBUG] Sessão salva e marcada como conectada. Status:', updated.status);
    });

    client.on('ready', async () => {
      // O evento 'ready' agora é apenas uma confirmação, não mais altera o banco.
      console.log(`[${sessionId}] CLIENTE PRONTO! Conexão totalmente estabelecida.`);
      this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!' });
    });
    // --- FIM DA CORREÇÃO ---
    
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

echo "-> whatsapp.service.ts atualizado com a lógica de salvamento atômica."