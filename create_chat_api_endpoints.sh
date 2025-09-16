#!/bin/bash

echo "--- Adicionando Endpoints de Chats e Mensagens na API Backend ---"
echo ""

# Navega para a pasta do backend
cd api

# --- Atualiza os arquivos da funcionalidade 'whatsapp' ---
echo "[1/3] Atualizando o whatsapp.service.ts com a lógica para buscar dados..."
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

  // --- NOVAS FUNÇÕES PARA BUSCAR DADOS ---
  public async getChats(sessionId: string) {
    const client = this.clients.get(sessionId);
    if (!client) {
      throw new Error('Sessão não encontrada ou não está pronta.');
    }
    const chats = await client.getChats();
    // Filtra para retornar apenas os dados que precisamos no frontend
    return chats.map(chat => ({
      id: chat.id._serialized,
      name: chat.name,
      isGroup: chat.isGroup,
      lastMessage: chat.lastMessage?.body,
      timestamp: chat.timestamp
    }));
  }

  public async getMessages(sessionId: string, chatId: string) {
    const client = this.clients.get(sessionId);
    if (!client) { throw new Error('Sessão não encontrada ou não está pronta.'); }
    
    const chat = await client.getChatById(chatId);
    // Busca as últimas 50 mensagens como exemplo
    const messages = await chat.fetchMessages({ limit: 50 });
    return messages;
  }
  // --- FIM DAS NOVAS FUNÇÕES ---

  public async listSessions(userId: string) {
    return prisma.whatsappSession.findMany({ where: { assignedToId: userId }, select: { id: true, name: true, status: true } });
  }

  public async initializeFromDb() {
    console.log('[DEBUG] Procurando por sessões com status CONNECTED...');
    const savedSessions = await prisma.whatsappSession.findMany({ where: { status: 'CONNECTED' } });
    console.log(`[SessionManager] ${savedSessions.length} sessões encontradas para recarregar.`);
    for (const session of savedSessions) { if (session.sessionData) { this.restoreSession(session.id, session.assignedToId!); } }
  }

  private restoreSession(sessionId: string, userId: string) {
    console.log(`[${sessionId}] Restaurando sessão...`);
    const client = new Client({ authStrategy: new LocalAuth({ clientId: sessionId }), puppeteer: { headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] } });
    client.on('ready', () => { console.log(`[${sessionId}] Sessão restaurada e pronta!`); });
    client.on('disconnected', async (reason) => { await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED' } }); this.clients.delete(sessionId); });
    client.on('message', (msg: Message) => { console.log(`[${sessionId}] Nova mensagem recebida de ${msg.from}: ${msg.body}`); });
    client.initialize();
    this.clients.set(sessionId, client);
  }

  public async createSession(userId: string) {
    console.log(`[SessionManager] Criando nova sessão para o usuário: ${userId}`);
    const newDbSession = await prisma.whatsappSession.create({ data: { name: `Sessão de ${userId.substring(0, 8)}`, status: "INITIALIZING", assignedToId: userId } });
    const sessionId = newDbSession.id;
    const client = new Client({ authStrategy: new LocalAuth({ clientId: sessionId }), puppeteer: { headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] } });
    client.on('qr', (qr) => this.io?.to(userId).emit('qr-code', qr));
    client.on('authenticated', async (session) => await prisma.whatsappSession.update({ where: { id: sessionId }, data: { sessionData: session as any } }));
    client.on('ready', async () => { await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'CONNECTED' } }); this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!' }); });
    client.on('disconnected', async (reason) => { await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED' } }); this.clients.delete(sessionId); });
    client.initialize();
    this.clients.set(sessionId, client);
  }
}
export const sessionManager = SessionManager.getInstance();
EOF
echo "  -> whatsapp.service.ts (Atualizado)"

echo "[2/3] Atualizando o whatsapp.controller.ts com os novos controladores..."
cat << 'EOF' > src/features/whatsapp/whatsapp.controller.ts
import { Response } from 'express';
import { AuthRequest } from '../../middleware/auth.middleware';
import { sessionManager } from './whatsapp.service';

export const connectWhatsappController = (req: AuthRequest, res: Response) => { /* ...código existente... */ try { const userId = req.user!.userId; sessionManager.createSession(userId); res.status(200).json({ message: 'Processo de conexão iniciado.' }); } catch (error) { res.status(500).json({ message: 'Erro ao iniciar a sessão.' }); } };
export const listSessionsController = async (req: AuthRequest, res: Response) => { /* ...código existente... */ try { const userId = req.user!.userId; const sessions = await sessionManager.listSessions(userId); res.status(200).json(sessions); } catch (error) { res.status(500).json({ message: 'Erro ao listar sessões.' }); } };

// --- NOVOS CONTROLADORES ---
export const getChatsController = async (req: AuthRequest, res: Response) => {
    try {
        const { sessionId } = req.params;
        const chats = await sessionManager.getChats(sessionId);
        res.status(200).json(chats);
    } catch (error) {
        res.status(500).json({ message: (error as Error).message });
    }
};

export const getMessagesController = async (req: AuthRequest, res: Response) => {
    try {
        const { sessionId, chatId } = req.params;
        const messages = await sessionManager.getMessages(sessionId, chatId);
        res.status(200).json(messages);
    } catch (error) {
        res.status(500).json({ message: (error as Error).message });
    }
};
EOF
echo "  -> whatsapp.controller.ts (Atualizado)"

echo "[3/3] Atualizando o whatsapp.routes.ts com as novas rotas..."
cat << 'EOF' > src/features/whatsapp/whatsapp.routes.ts
import { Router } from 'express';
import { protect } from '../../middleware/auth.middleware';
import { 
    connectWhatsappController, 
    listSessionsController,
    getChatsController,
    getMessagesController
} from './whatsapp.controller';

const router = Router();

// Rotas de Sessão
router.post('/sessions/connect', protect, connectWhatsappController);
router.get('/sessions', protect, listSessionsController);

// --- NOVAS ROTAS PARA CHATS E MENSAGENS ---
router.get('/sessions/:sessionId/chats', protect, getChatsController);
router.get('/sessions/:sessionId/chats/:chatId/messages', protect, getMessagesController);

export default router;
EOF
echo "  -> whatsapp.routes.ts (Atualizado)"
echo ""

echo "--- SUCESSO! Endpoints da API para chats e mensagens foram criados. ---"