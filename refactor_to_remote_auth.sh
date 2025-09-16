#!/bin/bash

echo "--- Refatorando o Backend para usar a Estratégia RemoteAuth ---"
echo ""

# Navega para a pasta do backend
cd api

# --- Passo 1: Criar a ponte Prisma <-> RemoteAuth ---
echo "[1/2] Criando o arquivo src/services/PrismaAuthStore.ts..."
mkdir -p src/services
cat << 'EOF' > src/services/PrismaAuthStore.ts
import { PrismaClient } from '@prisma/client';
import { Store } from 'whatsapp-web.js/src/authStrategies/RemoteAuth/Store';

const prisma = new PrismaClient();

// Esta classe implementa a interface que a RemoteAuth espera.
// Ela traduz os comandos de salvar/ler/deletar sessão para o nosso banco de dados.
export class PrismaAuthStore implements Store {
  private sessionId: string;

  constructor(sessionId: string) {
    this.sessionId = sessionId;
  }

  async save(session: any) {
    console.log(`[PrismaAuthStore] Salvando sessão para ${this.sessionId}`);
    await prisma.whatsappSession.update({
      where: { id: this.sessionId },
      data: { sessionData: session as any },
    });
  }

  async get() {
    console.log(`[PrismaAuthStore] Buscando sessão para ${this.sessionId}`);
    const session = await prisma.whatsappSession.findUnique({
      where: { id: this.sessionId },
    });
    return session?.sessionData as any;
  }

  async delete() {
    console.log(`[PrismaAuthStore] Deletando sessão para ${this.sessionId}`);
    await prisma.whatsappSession.update({
      where: { id: this.sessionId },
      data: { sessionData: null, status: 'DISCONNECTED' },
    });
  }
}
EOF
echo "  -> src/services/PrismaAuthStore.ts (Criado com sucesso!)"
echo ""

# --- Passo 2: Atualizar o whatsapp.service.ts para usar a nova estratégia ---
echo "[2/2] Atualizando o whatsapp.service.ts para a nova arquitetura..."
cat << 'EOF' > src/features/whatsapp/whatsapp.service.ts
import { Client, RemoteAuth } from 'whatsapp-web.js';
import { Server as SocketIOServer } from 'socket.io';
import { PrismaClient } from '@prisma/client';
import { PrismaAuthStore } from '../../services/PrismaAuthStore';

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
    console.log('[SessionManager] Verificando sessões salvas para recarregar...');
    const savedSessions = await prisma.whatsappSession.findMany({ where: { sessionData: { not: null } } });
    console.log(`[SessionManager] ${savedSessions.length} sessões encontradas.`);
    for (const session of savedSessions) { this.restoreSession(session.id, session.assignedToId!); }
  }

  private restoreSession(sessionId: string, userId: string) {
    console.log(`[${sessionId}] Restaurando sessão via RemoteAuth...`);
    const store = new PrismaAuthStore(sessionId);
    const client = new Client({ authStrategy: new RemoteAuth({ store, clientId: sessionId, backupSyncIntervalMs: 300000 }), puppeteer: { headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] } });
    this.clients.set(sessionId, client);
    client.on('ready', async () => { 
      console.log(`[${sessionId}] SESSÃO RESTAURADA E PRONTA!`); 
      await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'CONNECTED' } });
      this.io?.to(userId).emit('session-restored', { message: `Sessão ${sessionId} restaurada com sucesso!` }); 
    });
    client.on('remote_session_saved', () => console.log(`[${sessionId}] Sessão remota foi salva no banco de dados.`));
    client.on('disconnected', async (reason) => { await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED' } }); this.clients.delete(sessionId); });
    client.initialize().catch(err => console.error(`[${sessionId}] Falha ao inicializar cliente restaurado:`, err));
  }

  public async createSession(userId: string) {
    console.log(`[SessionManager] Criando nova sessão para o usuário: ${userId}`);
    const newDbSession = await prisma.whatsappSession.create({ data: { name: `Sessão de ${userId.substring(0, 8)}`, status: "INITIALIZING", assignedToId: userId } });
    const sessionId = newDbSession.id;
    
    // --- LÓGICA DE AUTENTICAÇÃO ATUALIZADA ---
    const store = new PrismaAuthStore(sessionId);
    const client = new Client({ 
      authStrategy: new RemoteAuth({ 
        store, 
        clientId: sessionId,
        backupSyncIntervalMs: 300000 // Salva a sessão no DB a cada 5 minutos
      }), 
      puppeteer: { headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] } 
    });
    
    this.clients.set(sessionId, client);

    client.on('qr', (qr) => { this.io?.to(userId).emit('qr-code', qr); });
    
    // O evento 'authenticated' não é mais necessário. A RemoteAuth cuida de tudo.
    // O novo evento 'remote_session_saved' nos informa quando o salvamento ocorreu.
    client.on('remote_session_saved', () => {
      console.log(`[${sessionId}] Sessão remota foi salva no banco de dados.`);
    });
    
    client.on('ready', async () => {
      console.log(`[${sessionId}] CLIENTE PRONTO! Atualizando status para CONNECTED...`);
      await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'CONNECTED' } });
      this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!' });
    });
    
    client.on('disconnected', async (reason) => { await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED' } }); this.clients.delete(sessionId); });
    client.initialize().catch(err => console.error(`[${sessionId}] Falha ao inicializar novo cliente:`, err));
  }
}
export const sessionManager = SessionManager.getInstance();
EOF
echo "  -> whatsapp.service.ts (Refatorado para RemoteAuth!)"
echo ""
echo "--- SUCESSO! O backend foi refatorado para a arquitetura correta. ---"