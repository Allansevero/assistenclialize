#!/bin/bash

echo "--- IMPLEMENTANDO A ARQUITETURA FINAL E COMPLETA DA FASE 3 ---"
echo "Isto irá reconfigurar o backend e o frontend para a versão estável com persistência isolada."
echo ""
sleep 2

# --- PARTE 1: RECONFIGURANDO O BACKEND ---
echo "[1/2] Reconfigurando o Backend..."
cd api

# 1.1 - Garante dependências
echo "Instalando dependências necessárias..."
npm install @whiskeysockets/baileys pino

# 1.2 - Cria o serviço de persistência ISOLADO
cat << 'EOF' > src/features/whatsapp/persistence.service.ts
import { PrismaClient } from '@prisma/client';
import fs from 'fs/promises';
import path from 'path';

const prisma = new PrismaClient();

class PersistenceService {
  private static instance: PersistenceService;
  private constructor() {}
  public static getInstance(): PersistenceService { if (!this.instance) { this.instance = new PersistenceService(); } return this.instance; }

  public async persistSession(userId: string) {
    console.log(`[PERSIST] Iniciando persistência da sessão para ${userId}...`);
    const sessionFolder = `auth_info_baileys/${userId}`;
    try {
      const credsFilePath = path.resolve(sessionFolder, 'creds.json');
      const credsContent = await fs.readFile(credsFilePath, { encoding: 'utf-8' });
      const credsJson = JSON.parse(credsContent);

      await prisma.whatsappSession.upsert({
        where: { assignedToId: userId },
        update: { sessionData: credsJson, status: 'CONNECTED' },
        create: {
          name: `Sessão ${userId.substring(0, 5)}...`,
          assignedToId: userId,
          sessionData: credsJson,
          status: 'CONNECTED',
        },
      });
      console.log(`[PERSIST] Sessão salva com sucesso no banco de dados!`);
    } catch (err) {
      console.error(`[PERSIST] Falha ao ler ou salvar credenciais:`, err);
      throw new Error('Failed to persist session');
    }
  }
}
export const persistenceService = PersistenceService.getInstance();
EOF
echo "  -> persistence.service.ts (OK)"

# 1.3 - Cria o serviço de conexão ESTÁVEL E INTOCADO
cat << 'EOF' > src/features/whatsapp/whatsapp.service.ts
import makeWASocket, {
  DisconnectReason,
  useMultiFileAuthState,
} from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import { Server as SocketIOServer } from 'socket.io';

class BaileysConnectionService {
  private static instance: BaileysConnectionService;
  public io: SocketIOServer | null = null;
  private constructor() {}
  public static getInstance(): BaileysConnectionService { if (!this.instance) { this.instance = new BaileysConnectionService(); } return this.instance; }

  public async createSession(userId: string) {
    const sessionFolder = `auth_info_baileys/${userId}`;
    const { state, saveCreds } = await useMultiFileAuthState(sessionFolder);
    const sock = makeWASocket({ auth: state, printQRInTerminal: false });
    
    sock.ev.on('connection.update', (update) => {
      const { connection, lastDisconnect, qr } = update;
      if (qr) { this.io?.to(userId).emit('qr-code', qr); }
      if (connection === 'close') {
        const shouldReconnect = (lastDisconnect?.error as Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
        if (shouldReconnect) { this.createSession(userId); }
      } else if (connection === 'open') {
        this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!' });
      }
    });
    sock.ev.on('creds.update', saveCreds);
  }
}
export const connectionService = BaileysConnectionService.getInstance();
EOF
echo "  -> whatsapp.service.ts (OK)"

# 1.4 - Cria o controller que ORQUESTRA os dois serviços
cat << 'EOF' > src/features/whatsapp/whatsapp.controller.ts
import { Response } from 'express';
import { AuthRequest } from '../../middleware/auth.middleware';
import { connectionService } from './whatsapp.service';
import { persistenceService } from './persistence.service';

export const connectWhatsappController = (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user!.userId;
        connectionService.createSession(userId);
        res.status(200).json({ message: 'Processo de conexão iniciado.' });
    } catch (error) {
        res.status(500).json({ message: 'Erro ao iniciar a sessão.' });
    }
};

export const persistSessionController = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user!.userId;
        await persistenceService.persistSession(userId);
        res.status(200).json({ message: 'Sessão persistida com sucesso.'});
    } catch (error) {
        res.status(500).json({ message: 'Erro ao persistir a sessão.'});
    }
};
EOF
echo "  -> whatsapp.controller.ts (OK)"

# 1.5 - Cria as rotas
cat << 'EOF' > src/features/whatsapp/whatsapp.routes.ts
import { Router } from 'express';
import { protect } from '../../middleware/auth.middleware';
import { connectWhatsappController, persistSessionController } from './whatsapp.controller';

const router = Router();
router.post('/sessions/connect', protect, connectWhatsappController);
router.post('/sessions/persist', protect, persistSessionController);
export default router;
EOF
echo "  -> whatsapp.routes.ts (OK)"

# 1.6 - Cria o server.ts que usa a referência correta
cat << 'EOF' > src/server.ts
import express from 'express';
import cors from 'cors';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';

import authRoutes from './features/auth/auth.routes';
import teamRoutes from './features/teams/teams.routes';
import whatsappRoutes from './features/whatsapp/whatsapp.routes';
import { connectionService } from './features/whatsapp/whatsapp.service';

const app = express();
const server = http.createServer(app);
const io = new SocketIOServer(server, { cors: { origin: '*' } });

// Injeta a instância do socket.io no serviço de conexão
connectionService.io = io;

const PORT = process.env.PORT || 3000;
app.use(cors({ origin: '*' }));
app.use(express.json());
app.use('/api/auth', authRoutes);
app.use('/api/teams', teamRoutes);
app.use('/api/whatsapp', whatsappRoutes);

io.on('connection', (socket) => {
  socket.on('join-room', (userId) => socket.join(userId));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor rodando em http://localhost:${PORT}`);
});
EOF
echo "  -> server.ts (OK)"
echo "Backend configurado com sucesso."
echo ""

# --- PARTE 2: RECONFIGURANDO O FRONTEND ---
echo "[2/2] Reconfigurando o Frontend..."
cd ../src

# 2.1 - Atualiza a página de conexão
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

  useEffect(() => {
    socket = io('http://localhost:3000');
    if (user) { socket.emit('join-room', user.id); }
    socket.on('qr-code', (qr: string) => { setQrCode(qr); setStatus('Aguardando escaneamento...'); });
    socket.on('session-ready', (data) => {
      toast.success(data.message);
      setStatus('Conectado! Salvando no banco de dados...');
      api.post(`/whatsapp/sessions/persist`, {}, { headers: { Authorization: `Bearer ${token}` } })
        .then(() => {
          toast.success('Sessão salva com sucesso no banco de dados!');
          setStatus('Conectado e Salvo no DB!');
        })
        .catch(() => {
          toast.error('Falha ao salvar a sessão no banco.');
          setStatus('Conectado, mas falha ao salvar no DB.');
        });
      setQrCode(null);
    });
    return () => { socket.disconnect(); };
  }, [user, token]);

  async function handleStartConnection() {
    setStatus('Iniciando conexão...');
    setQrCode(null);
    try {
      await api.post('/whatsapp/sessions/connect', {}, { headers: { Authorization: `Bearer ${token}` } });
      setStatus('Aguardando o QR Code...');
    } catch (error) {
      toast.error('Não foi possível iniciar a conexão.');
      setStatus('Erro.');
    }
  }

  return (
    <div className="p-8">
      <Link to="/dashboard">&larr; Voltar</Link>
      <h1 className="text-2xl font-bold mt-4">Conectar Nova Conta de WhatsApp</h1>
      <div className="mt-4 p-4 border rounded-md">
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
echo "  -> ConnectWhatsAppPage.tsx (OK)"
echo ""
echo "--- SUCESSO! A ARQUITETURA FINAL FOI REIMPLEMENTADA. ---"