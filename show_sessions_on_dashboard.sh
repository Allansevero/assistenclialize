#!/bin/bash

echo "--- Iniciando a Integração do Dashboard com a Lista de Sessões ---"
echo ""

# --- Passo 1: Atualizar o Backend ---
echo "[1/2] Adicionando o endpoint de listagem de sessões no Backend..."
cd api

# 1.1 - Atualiza o whatsapp.service.ts
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
  
  // --- NOVA FUNÇÃO PARA LISTAR SESSÕES DE UM USUÁRIO ---
  public async listSessions(userId: string) {
    console.log(`[SessionManager] Buscando sessões para o usuário: ${userId}`);
    const sessions = await prisma.whatsappSession.findMany({
      where: { assignedToId: userId },
      select: { id: true, name: true, status: true }, // Seleciona apenas os campos seguros
    });
    return sessions;
  }

  public async initializeFromDb() {
    console.log('[DEBUG] Procurando por sessões com status CONNECTED...');
    const savedSessions = await prisma.whatsappSession.findMany({ where: { status: 'CONNECTED' } });
    console.log(`[SessionManager] ${savedSessions.length} sessões encontradas para recarregar.`);
    if (savedSessions.length > 0) { console.log('[DEBUG] Sessões encontradas:', savedSessions.map(s => ({ id: s.id, name: s.name, status: s.status }))); }
    for (const session of savedSessions) { if (session.sessionData) { this.restoreSession(session.id, session.assignedToId!); } }
  }

  private restoreSession(sessionId: string, userId: string) {
    console.log(`[${sessionId}] Restaurando sessão...`);
    const client = new Client({ authStrategy: new LocalAuth({ clientId: sessionId }), puppeteer: { headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] } });
    client.on('ready', async () => { console.log(`[${sessionId}] Sessão restaurada e pronta!`); this.io?.to(userId).emit('session-restored', { message: `Sessão ${sessionId} restaurada com sucesso!` }); });
    client.on('disconnected', async (reason) => { console.log(`[${sessionId}] Cliente (restaurado) foi desconectado:`, reason); await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED' } }); this.clients.delete(sessionId); });
    client.on('message', (msg: Message) => { console.log(`[${sessionId}] Nova mensagem recebida de ${msg.from}: ${msg.body}`); });
    client.initialize();
    this.clients.set(sessionId, client);
  }

  public async createSession(userId: string) {
    console.log(`[SessionManager] Criando nova sessão para o usuário: ${userId}`);
    const newDbSession = await prisma.whatsappSession.create({ data: { name: `Sessão de ${userId.substring(0, 8)}`, status: "INITIALIZING", assignedToId: userId } });
    const sessionId = newDbSession.id;
    console.log(`[${sessionId}] Registro da sessão criado no banco de dados.`);
    const client = new Client({ authStrategy: new LocalAuth({ clientId: sessionId }), puppeteer: { headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] } });
    client.on('qr', (qr) => { console.log(`[${sessionId}] QR Code recebido...`); this.io?.to(userId).emit('qr-code', qr); });
    client.on('authenticated', async (session) => { console.log(`[${sessionId}] Autenticado! Salvando...`); const updatedSession = await prisma.whatsappSession.update({ where: { id: sessionId }, data: { sessionData: session as any } }); console.log('[DEBUG] sessionData preenchido? ', !!updatedSession.sessionData); });
    client.on('ready', async () => { console.log(`[${sessionId}] Cliente pronto! Status: CONNECTED...`); const updatedSession = await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'CONNECTED' } }); console.log('[DEBUG] Novo status:', updatedSession.status); this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!' }); });
    client.on('disconnected', async (reason) => { console.log(`[${sessionId}] Desconectado:`, reason); await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED' } }); this.clients.delete(sessionId); });
    client.initialize();
    this.clients.set(sessionId, client);
  }
}
export const sessionManager = SessionManager.getInstance();
EOF
echo "  -> api/src/features/whatsapp/whatsapp.service.ts (Atualizado)"

# 1.2 - Atualiza o whatsapp.controller.ts
cat << 'EOF' > src/features/whatsapp/whatsapp.controller.ts
import { Response } from 'express';
import { AuthRequest } from '../../middleware/auth.middleware';
import { sessionManager } from './whatsapp.service';

export const connectWhatsappController = (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    sessionManager.createSession(userId);
    res.status(200).json({ message: 'Processo de conexão iniciado.' });
  } catch (error) {
    res.status(500).json({ message: 'Erro ao iniciar a sessão.' });
  }
};

// --- NOVO CONTROLLER PARA LISTAR SESSÕES ---
export const listSessionsController = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user!.userId;
        const sessions = await sessionManager.listSessions(userId);
        res.status(200).json(sessions);
    } catch (error) {
        res.status(500).json({ message: 'Erro ao listar sessões.' });
    }
};
EOF
echo "  -> api/src/features/whatsapp/whatsapp.controller.ts (Atualizado)"

# 1.3 - Atualiza o whatsapp.routes.ts
cat << 'EOF' > src/features/whatsapp/whatsapp.routes.ts
import { Router } from 'express';
import { protect } from '../../middleware/auth.middleware';
import { connectWhatsappController, listSessionsController } from './whatsapp.controller';

const router = Router();

// Endpoint para iniciar uma nova conexão
router.post('/sessions/connect', protect, connectWhatsappController);

// --- NOVA ROTA PARA LISTAR SESSÕES ---
router.get('/sessions', protect, listSessionsController);

export default router;
EOF
echo "  -> api/src/features/whatsapp/whatsapp.routes.ts (Atualizado)"
echo "Backend atualizado com sucesso."
echo ""

# --- Passo 2: Atualizar o Frontend ---
echo "[2/2] Atualizando o Dashboard no Frontend para exibir as sessões..."
cd ../src # Volta para a raiz e entra no frontend

cat << 'EOF' > src/pages/Dashboard.tsx
import { useEffect, useState } from "react";
import { useAuthStore } from "../stores/auth.store";
import { Link, useNavigate } from "react-router-dom";
import { api } from "../lib/api";

// Define a tipagem de uma sessão para o frontend
interface WhatsappSession {
  id: string;
  name: string | null;
  status: string;
}

export function DashboardPage() {
  const { user, token, logout } = useAuthStore();
  const navigate = useNavigate();
  const [sessions, setSessions] = useState<WhatsappSession[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    async function fetchSessions() {
      if (!token) return;
      try {
        setIsLoading(true);
        const response = await api.get('/whatsapp/sessions', {
          headers: { Authorization: `Bearer ${token}` }
        });
        setSessions(response.data);
      } catch (error) {
        console.error("Erro ao buscar sessões:", error);
      } finally {
        setIsLoading(false);
      }
    }
    fetchSessions();
  }, [token]);

  function handleLogout() {
    logout();
    navigate('/login');
  }
  
  return (
    <div className="p-8 max-w-4xl mx-auto">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold">Bem-vindo, {user?.name}!</h1>
        <button onClick={handleLogout} className="px-4 py-2 text-white bg-red-600 rounded hover:bg-red-700">Sair (Logout)</button>
      </div>
      
      <div>
        <div className="flex justify-between items-center">
            <h2 className="text-2xl font-semibold">Suas Conexões</h2>
            <Link to="/connect-whatsapp">
                <button className="px-4 py-2 text-white bg-green-600 rounded hover:bg-green-700">+ Conectar Nova Conta</button>
            </Link>
        </div>
        
        <div className="mt-4 p-4 border rounded-md bg-white shadow-sm">
          {isLoading ? (
            <p>Carregando sessões...</p>
          ) : sessions.length > 0 ? (
            <ul className="space-y-3">
              {sessions.map(session => (
                <li key={session.id} className="p-3 border rounded-lg flex justify-between items-center">
                  <span>{session.name || session.id}</span>
                  <span className={`px-3 py-1 text-sm rounded-full ${session.status === 'CONNECTED' ? 'bg-green-200 text-green-800' : 'bg-gray-200 text-gray-800'}`}>
                    {session.status}
                  </span>
                </li>
              ))}
            </ul>
          ) : (
            <p>Nenhuma sessão conectada ainda.</p>
          )}
        </div>
      </div>
    </div>
  )
}
EOF
echo "  -> src/pages/Dashboard.tsx (Atualizado)"
echo "Frontend atualizado com sucesso."
echo ""
echo "--- SUCESSO! O ciclo está completo. O Dashboard agora exibe as sessões do backend. ---"