#!/bin/bash

echo "--- VINCULANDO A CRIAÇÃO DA SESSÃO AO BANCO DE DADOS ---"
echo ""

# --- PARTE 1: ATUALIZANDO O BACKEND ---
echo "[1/2] Refatorando o Backend..."
cd api

# 1.1 - Reescreve o service para usar o ID da sessão do DB
cat << 'EOF' > src/features/whatsapp/whatsapp.service.ts
import makeWASocket, {
  DisconnectReason,
  useMultiFileAuthState,
} from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import { Server as SocketIOServer } from 'socket.io';
import { PrismaClient } from '@prisma/client';
import fs from 'fs/promises';
import path from 'path';

const prisma = new PrismaClient();

class BaileysSessionManager {
  private static instance: BaileysSessionManager;
  public io: SocketIOServer | null = null;
  private constructor() {}
  public static getInstance(): BaileysSessionManager { if (!this.instance) { this.instance = new BaileysSessionManager(); } return this.instance; }

  // A criação agora recebe o ID da sessão do DB para criar a pasta
  public async createSession(sessionId: string, userId: string) {
    const sessionFolder = `auth_info_baileys/session-${sessionId}`;
    const { state, saveCreds } = await useMultiFileAuthState(sessionFolder);
    const sock = makeWASocket({ auth: state, printQRInTerminal: false });
    
    sock.ev.on('connection.update', (update) => {
      const { connection, lastDisconnect, qr } = update;
      if (qr) { this.io?.to(userId).emit('qr-code', qr); }
      if (connection === 'close') {
        prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED' } }).catch(console.error);
      } else if (connection === 'open') {
        console.log(`[${sessionId}] Conexão aberta com sucesso!`);
        this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!', sessionId });
      }
    });
    sock.ev.on('creds.update', saveCreds);
  }
  
  public async persistSession(sessionId: string) {
    console.log(`[${sessionId}] [PERSIST] Iniciando persistência...`);
    const sessionFolder = `auth_info_baileys/session-${sessionId}`;
    try {
      const credsFilePath = path.resolve(sessionFolder, 'creds.json');
      const credsContent = await fs.readFile(credsFilePath, { encoding: 'utf-8' });
      const credsJson = JSON.parse(credsContent);

      await prisma.whatsappSession.update({
        where: { id: sessionId },
        data: { sessionData: credsJson, status: 'CONNECTED' },
      });
      console.log(`[${sessionId}] [PERSIST] Sessão salva com sucesso no banco de dados!`);
      return { success: true };
    } catch (err) {
      console.error(`[${sessionId}] [PERSIST] Falha ao salvar no DB:`, err);
      throw new Error('Failed to persist session');
    }
  }

  // Funções placeholder
  public async getChats(sessionId: string) { return []; }
  public async getMessages(sessionId: string, chatId: string) { return []; }
}
export const sessionManager = BaileysSessionManager.getInstance();
EOF
echo "  -> whatsapp.service.ts (OK)"

# 1.2 - Atualiza o controller para criar a linha no DB primeiro
cat << 'EOF' > src/features/whatsapp/whatsapp.controller.ts
import { Response } from 'express';
import { AuthRequest } from '../../middleware/auth.middleware';
import { PrismaClient } from '@prisma/client';
import { sessionManager } from './whatsapp.service';

const prisma = new PrismaClient();

// CONTROLLER ATUALIZADO
export const connectWhatsappController = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    // PRIMEIRO, cria a linha no banco de dados
    const dbSession = await prisma.whatsappSession.create({
      data: {
        name: `Sessão ${userId.substring(0, 5)}...`,
        assignedToId: userId,
        status: 'INITIALIZING',
      },
    });
    // SEGUNDO, inicia a conexão do Baileys usando o ID do DB
    sessionManager.createSession(dbSession.id, userId);
    // TERCEIRO, retorna o ID para o frontend
    res.status(200).json({ message: 'Processo de conexão iniciado.', sessionId: dbSession.id });
  } catch (error) {
    res.status(500).json({ message: 'Erro ao iniciar a sessão.' });
  }
};

export const persistSessionController = async (req: AuthRequest, res: Response) => {
  try {
    const { sessionId } = req.params; // O frontend nos dirá qual sessão persistir
    await sessionManager.persistSession(sessionId);
    res.status(200).json({ message: 'Sessão persistida com sucesso.'});
  } catch (error) {
    res.status(500).json({ message: 'Erro ao persistir a sessão.'});
  }
};

export const listSessionsController = async (req: AuthRequest, res: Response) => { /* ...código existente... */ try { const userId = req.user!.userId; const sessions = await prisma.whatsappSession.findMany({ where: { assignedToId: userId }, select: { id: true, name: true, status: true } }); res.status(200).json(sessions); } catch (error) { res.status(500).json({ message: 'Erro ao listar sessões.' }); }};
export const getChatsController = async (req: AuthRequest, res: Response) => res.status(501).json({ message: 'Not implemented for Baileys yet.' });
export const getMessagesController = async (req: AuthRequest, res: Response) => res.status(501).json({ message: 'Not implemented for Baileys yet.' });
EOF
echo "  -> whatsapp.controller.ts (OK)"

# 1.3 - Atualiza as rotas (sem mudanças, mas garantindo a integridade)
cat << 'EOF' > src/features/whatsapp/whatsapp.routes.ts
import { Router } from 'express';
import { protect } from '../../middleware/auth.middleware';
import { connectWhatsappController, listSessionsController, persistSessionController } from './whatsapp.controller';

const router = Router();
router.post('/sessions/connect', protect, connectWhatsappController);
router.post('/sessions/:sessionId/persist', protect, persistSessionController); // Rota atualizada para receber o ID
router.get('/sessions', protect, listSessionsController);
export default router;
EOF
echo "  -> whatsapp.routes.ts (OK)"
echo "Backend atualizado com sucesso."
echo ""

# --- PARTE 2: ATUALIZANDO O FRONTEND ---
echo "[2/2] Atualizando o Frontend para o novo fluxo..."
cd ../src

cat << 'EOF' > src/pages/ConnectWhatsAppPage.tsx
import { useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import { useAuthStore } from '../stores/auth.store';
import { api } from '../lib/api';
import QRCode from 'react-qr-code';
import toast from 'react-hot-toast';
import { Link } from 'react-router-dom';

let socket: Socket;

export function ConnectWhatsAppPage() {
  const { user, token } = useAuthStore();
  const [qrCode, setQrCode] = useState<string | null>(null);
  const [status, setStatus] = useState('Ocioso');
  const [currentSessionId, setCurrentSessionId] = useState<string | null>(null);

  useEffect(() => {
    socket = io('http://localhost:3000');
    if (user) { socket.emit('join-room', user.id); }
    socket.on('qr-code', (qr: string) => { setQrCode(qr); setStatus('Aguardando escaneamento...'); });
    
    // O evento 'session-ready' agora nos dá o ID da sessão
    socket.on('session-ready', (data) => {
      toast.success(data.message);
      setStatus('Conectado! Salvando no banco de dados...');
      
      api.post(`/whatsapp/sessions/${data.sessionId}/persist`, {}, {
        headers: { Authorization: `Bearer ${token}` }
      }).then(() => {
        toast.success('Sessão salva com sucesso no banco de dados!');
        setStatus('Conectado e Salvo no DB!');
      }).catch(() => { toast.error('Falha ao salvar a sessão no banco.'); });
      
      setQrCode(null);
    });

    return () => { socket.disconnect(); };
  }, [user, token]);

  async function handleStartConnection() {
    setStatus('Iniciando conexão...');
    setQrCode(null);
    try {
      const response = await api.post('/whatsapp/sessions/connect', {}, { headers: { Authorization: `Bearer ${token}` } });
      // Salva o ID da sessão retornado pela API no estado
      setCurrentSessionId(response.data.sessionId);
      setStatus('Aguardando o QR Code...');
    } catch (error) {
      toast.error('Não foi possível iniciar a conexão.');
      setStatus('Erro.');
    }
  }

  return (
    <div className="p-8">
      <Link to="/dashboard">&larr; Voltar</Link>
      <h1>Conectar Nova Conta de WhatsApp</h1>
      <div>
        <p><b>Status:</b> {status}</p>
        <button onClick={handleStartConnection} disabled={status !== 'Ocioso' && status !== 'Erro.'}>Iniciar Conexão</button>
        {qrCode && (
          <div className="mt-6">
            <p>Escaneie o QR Code:</p>
            <div style={{ background: 'white', padding: '16px' }}><QRCode value={qrCode} size={256} /></div>
          </div>
        )}
      </div>
    </div>
  );
}
EOF
echo "  -> ConnectWhatsAppPage.tsx (Atualizado)"
echo ""
echo "--- SUCESSO! A arquitetura final foi implementada. ---"