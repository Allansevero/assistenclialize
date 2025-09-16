#!/bin/bash

echo "--- CONSTRUINDO A FUNCIONALIDADE WHATSAPP DE FORMA ROBUSTA E ESTRUTURADA ---"
echo ""
sleep 2

# --- PASSO 1: ATUALIZAR O BANCO DE DADOS ---
echo "[1/6] Atualizando o schema do Prisma para incluir o modelo WhatsappSession..."
cd api

cat << 'EOF' > prisma/schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

model User {
  id        String    @id @default(cuid())
  email     String    @unique
  name      String
  password  String
  role      UserRole  @default(MEMBER)
  teamId    String?
  team      Team?     @relation(fields: [teamId], references: [id])
  sessions  WhatsappSession[] @relation("UserSessions")
}

model Team {
  id      String   @id @default(cuid())
  name    String
  ownerId String   @unique
  members User[]
}

model WhatsappSession {
  id            String    @id @default(cuid())
  name          String?
  status        String    @default("DISCONNECTED") // Ex: INITIALIZING, AWAITING_QR, CONNECTED, DISCONNECTED
  sessionData   Json?
  
  assignedToId  String
  assignedTo    User      @relation("UserSessions", fields: [assignedToId], references: [id])
}

enum UserRole {
  ADMIN
  MEMBER
}
EOF
echo "  -> Schema do Prisma atualizado."
echo ""

# --- PASSO 2: INSTALAR DEPENDÊNCIAS E CRIAR ESTRUTURA ---
echo "[2/6] Instalando dependências (pino) e criando a estrutura de pastas..."
npm install pino @types/pino # Pino é uma biblioteca de logging rápida
mkdir -p src/features/whatsapp
mkdir -p src/services
echo "  -> Estrutura de pastas criada."
echo ""

# --- PASSO 3: CRIAR OS SERVIÇOS DE SUPORTE (AUTH E SOCKET) ---
echo "[3/6] Criando o PrismaAuthStore e o SocketManager..."

# Auth Store
cat << 'EOF' > src/features/whatsapp/PrismaAuthStore.ts
import { PrismaClient } from '@prisma/client';
import { proto } from '@whiskeysockets/baileys';

const prisma = new PrismaClient();

const stringifyAuth = (data: object) => {
    return JSON.stringify(data, (_, v) => {
        if (v instanceof Buffer) return { type: 'Buffer', data: v.toString('base64') };
        if (v instanceof Uint8Array) return { type: 'Buffer', data: Buffer.from(v).toString('base64') };
        return v;
    });
};

const parseAuth = (json: object) => {
    return JSON.parse(JSON.stringify(json), (_, v) => {
        if (v && v.type === 'Buffer' && typeof v.data === 'string') {
            return Buffer.from(v.data, 'base64');
        }
        return v;
    });
};

export class PrismaAuthStore {
    private sessionId: string;

    constructor(sessionId: string) {
        this.sessionId = sessionId;
    }

    public async readData(): Promise<any> {
        try {
            const session = await prisma.whatsappSession.findUnique({ where: { id: this.sessionId } });
            return session?.sessionData ? parseAuth(session.sessionData) : null;
        } catch (e) {
            console.error(`Falha ao ler a sessão ${this.sessionId} do DB.`, e);
            return null;
        }
    }

    public async writeData(data: any): Promise<void> {
        try {
            const sessionDataString = stringifyAuth(data);
            await prisma.whatsappSession.update({
                where: { id: this.sessionId },
                data: { sessionData: JSON.parse(sessionDataString) },
            });
        } catch (e) {
            console.error(`Falha ao salvar a sessão ${this.sessionId} no DB.`, e);
        }
    }
}
EOF

# Socket Manager
cat << 'EOF' > src/services/socket.manager.ts
import { Server as SocketIOServer } from 'socket.io';
import http from 'http';

class SocketManager {
    private static instance: SocketManager;
    public io: SocketIOServer | null = null;

    private constructor() { }

    public static getInstance(): SocketManager {
        if (!this.instance) {
            this.instance = new SocketManager();
        }
        return this.instance;
    }

    public initialize(server: http.Server) {
        this.io = new SocketIOServer(server, { cors: { origin: '*' } });
        this.io.on('connection', (socket) => {
            console.log(`[Socket.IO] Novo cliente conectado: ${socket.id}`);
            socket.on('join-room', (userId) => {
                console.log(`[Socket.IO] Cliente ${socket.id} entrou na sala ${userId}`);
                socket.join(userId);
            });
        });
    }

    public emitToUser(userId: string, event: string, data: any) {
        this.io?.to(userId).emit(event, data);
    }
}

export const socketManager = SocketManager.getInstance();
EOF
echo "  -> Serviços de suporte criados."
echo ""

# --- PASSO 4: CRIAR O SERVIÇO, CONTROLLER E ROTAS PRINCIPAIS ---
echo "[4/6] Criando os arquivos principais da funcionalidade WhatsApp..."

# Service (O Orquestrador)
cat << 'EOF' > src/features/whatsapp/whatsapp.service.ts
import makeWASocket, { DisconnectReason, fetchLatestBaileysVersion } from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import { PrismaClient } from '@prisma/client';
import pino from 'pino';
import { PrismaAuthStore } from './PrismaAuthStore';
import { socketManager } from '../../services/socket.manager';

const prisma = new PrismaClient();
const logger = pino({ level: 'debug' });

class SessionManager {
    private static instance: SessionManager;
    private clients: Map<string, any> = new Map();

    private constructor() { }
    public static getInstance(): SessionManager {
        if (!this.instance) { this.instance = new SessionManager(); }
        return this.instance;
    }

    public async startNewSession(userId: string, sessionName: string = 'Nova Sessão') {
        const session = await prisma.whatsappSession.create({
            data: { name: sessionName, assignedToId: userId, status: 'INITIALIZING' }
        });
        this.initializeSocket(session.id, userId);
        return session;
    }

    private async initializeSocket(sessionId: string, userId: string) {
        if (this.clients.has(sessionId)) return;
        logger.info(`[${sessionId}] Inicializando socket...`);

        const authStore = new PrismaAuthStore(sessionId);
        const initialData = await authStore.readData();

        const { state, saveCreds } = {
            state: {
                creds: initialData?.creds || { noiseKey: {}, signedIdentityKey: {}, signedPreKey: {}, registrationId: 0, advSecretKey: '', processedHistoryMessages: [], nextPreKeyId: 0, firstUnuploadedPreKeyId: 0, accountSettings: { unarchiveChats: false } },
                keys: initialData?.keys || {},
            },
            saveCreds: () => authStore.writeData({ creds: state.creds, keys: state.keys }),
        };

        const { version } = await fetchLatestBaileysVersion();
        const sock = makeWASocket({ version, auth: state, printQRInTerminal: false, logger });
        this.clients.set(sessionId, sock);

        sock.ev.on('creds.update', saveCreds);
        sock.ev.on('connection.update', async ({ connection, lastDisconnect, qr }) => {
            if (qr) {
                socketManager.emitToUser(userId, 'qr-code', { sessionId, qr });
                await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'AWAITING_QR' } });
            }
            if (connection === 'close') {
                const status = (lastDisconnect?.error as Boom)?.output?.statusCode;
                this.clients.delete(sessionId);
                if (status !== DisconnectReason.loggedOut) {
                    this.initializeSocket(sessionId, userId);
                } else {
                    await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED', sessionData: null } });
                }
            } else if (connection === 'open') {
                await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'CONNECTED' } });
                socketManager.emitToUser(userId, 'session-status', { sessionId, status: 'CONNECTED' });
            }
        });
    }

    public async restoreAllSessions() {
        logger.info('[SessionManager] Restaurando todas as sessões salvas...');
        const sessions = await prisma.whatsappSession.findMany({ where: { status: 'CONNECTED' } });
        for (const session of sessions) {
            this.initializeSocket(session.id, session.assignedToId);
        }
    }
}

export const sessionManager = SessionManager.getInstance();
EOF

# Controller
cat << 'EOF' > src/features/whatsapp/whatsapp.controller.ts
import { Response } from 'express';
import { AuthRequest } from '../../middleware/auth.middleware';
import { PrismaClient } from '@prisma/client';
import { sessionManager } from './whatsapp.service';

const prisma = new PrismaClient();

export const connectNewSessionController = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user!.userId;
        const session = await sessionManager.startNewSession(userId);
        res.status(201).json({ message: 'Processo de conexão iniciado.', session });
    } catch (error) {
        res.status(500).json({ message: 'Erro ao iniciar a sessão.' });
    }
};

export const listSessionsController = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user!.userId;
        const sessions = await prisma.whatsappSession.findMany({
            where: { assignedToId: userId },
            select: { id: true, name: true, status: true }
        });
        res.status(200).json(sessions);
    } catch (error) {
        res.status(500).json({ message: 'Erro ao listar sessões.' });
    }
};
EOF

# Routes
cat << 'EOF' > src/features/whatsapp/whatsapp.routes.ts
import { Router } from 'express';
import { protect } from '../../middleware/auth.middleware';
import { connectNewSessionController, listSessionsController } from './whatsapp.controller';

const router = Router();
router.post('/sessions/connect', protect, connectNewSessionController);
router.get('/sessions', protect, listSessionsController);

export default router;
EOF
echo "  -> Arquivos principais criados."
echo ""

# --- PASSO 5: ATUALIZAR O SERVIDOR PRINCIPAL ---
echo "[5/6] Atualizando o server.ts para a nova arquitetura..."
cat << 'EOF' > src/server.ts
import express from 'express';
import cors from 'cors';
import http from 'http';
import { socketManager } from './services/socket.manager';
import { sessionManager } from './features/whatsapp/whatsapp.service';

import authRoutes from './features/auth/auth.routes';
import teamRoutes from './features/teams/teams.routes';
import whatsappRoutes from './features/whatsapp/whatsapp.routes';

const app = express();
const server = http.createServer(app);

// Inicializa o Socket.IO através do manager
socketManager.initialize(server);

const PORT = process.env.PORT || 3000;
app.use(cors({ origin: '*' }));
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/teams', teamRoutes);
app.use('/api/whatsapp', whatsappRoutes);

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor rodando em http://localhost:${PORT}`);
  // Restaura todas as sessões ativas do banco de dados na inicialização
  sessionManager.restoreAllSessions();
});
EOF
echo "  -> Servidor principal atualizado."
echo ""

# --- PASSO 6: ATUALIZAR O FRONTEND ---
echo "[6/6] Atualizando o frontend para a nova arquitetura..."
cd ../src

# Cria a página de conexão
cat << 'EOF' > src/pages/ConnectWhatsAppPage.tsx
import { useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import QRCode from 'react-qr-code';
import toast from 'react-hot-toast';
import { Link } from 'react-router-dom';
import { useAuthStore } from '../stores/auth.store';
import { api } from '../lib/api';

let socket: Socket;

export function ConnectWhatsAppPage() {
    const { user, token } = useAuthStore();
    const [qrCode, setQrCode] = useState<string | null>(null);
    const [status, setStatus] = useState('Ocioso');
    const [currentSessionId, setCurrentSessionId] = useState<string | null>(null);

    useEffect(() => {
        socket = io('http://localhost:3000');
        if (user) {
            socket.emit('join-room', user.id);
        }

        socket.on('qr-code', (data: { sessionId: string; qr: string }) => {
            if (data.sessionId === currentSessionId) {
                setQrCode(data.qr);
                setStatus('Aguardando escaneamento...');
            }
        });

        socket.on('session-status', (data: { sessionId: string; status: string }) => {
            if (data.sessionId === currentSessionId && data.status === 'CONNECTED') {
                toast.success('Sessão conectada com sucesso!');
                setStatus('Conectado!');
                setQrCode(null);
            }
        });

        return () => { socket.disconnect(); };
    }, [user, currentSessionId]);

    async function handleStartConnection() {
        setStatus('Iniciando conexão...');
        try {
            const response = await api.post('/whatsapp/sessions/connect', {}, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setCurrentSessionId(response.data.session.id);
            setStatus('Aguardando QR Code...');
        } catch (error) {
            toast.error('Não foi possível iniciar a conexão.');
            setStatus('Erro.');
        }
    }

    return (
        <div className="p-8">
            <Link to="/dashboard">&larr; Voltar para o Dashboard</Link>
            <h1 className="text-2xl font-bold mt-4">Conectar Nova Conta</h1>
            <div className="mt-4 p-4 border rounded-md">
                <p><b>Status:</b> {status}</p>
                <button onClick={handleStartConnection} disabled={status !== 'Ocioso' && status !== 'Erro.'}>
                    Gerar QR Code
                </button>
                {qrCode && (
                    <div className="mt-6">
                        <p>Escaneie o QR Code com seu celular:</p>
                        <div style={{ background: 'white', padding: '16px' }}>
                            <QRCode value={qrCode} size={256} />
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
EOF

# Atualiza o App.tsx
cat << 'EOF' > src/App.tsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { LoginPage } from './pages/Login';
import { RegisterPage } from './pages/Register';
import { DashboardPage } from './pages/Dashboard';
import { ConnectWhatsAppPage } from './pages/ConnectWhatsAppPage';
import { Toaster } from 'react-hot-toast';
import { useAuthStore } from './stores/auth.store';

const ProtectedRoute = ({ children }: { children: React.ReactNode }) => {
    const { token } = useAuthStore();
    return token ? children : <Navigate to="/login" />;
};

function App() {
    return (
        <BrowserRouter>
            <Toaster position="top-right" />
            <Routes>
                <Route path="/login" element={<LoginPage />} />
                <Route path="/register" element={<RegisterPage />} />
                <Route path="/" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
                <Route path="/dashboard" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
                <Route path="/connect-whatsapp" element={<ProtectedRoute><ConnectWhatsAppPage /></ProtectedRoute>} />
            </Routes>
        </BrowserRouter>
    );
}

export default App;
EOF

# Atualiza o Dashboard.tsx
cat << 'EOF' > src/pages/Dashboard.tsx
import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuthStore } from "../stores/auth.store";
import { api } from "../lib/api";

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
        <button onClick={handleLogout} className="px-4 py-2 text-white bg-red-600 rounded hover:bg-red-700">Sair</button>
      </div>
      <div>
        <div className="flex justify-between items-center">
            <h2 className="text-2xl font-semibold">Suas Conexões</h2>
            <Link to="/connect-whatsapp">
                <button className="px-4 py-2 text-white bg-green-600 rounded hover:bg-green-700">+ Conectar Nova Conta</button>
            </Link>
        </div>
        <div className="mt-4 p-4 border rounded-md bg-white shadow-sm">
          {isLoading ? <p>Carregando sessões...</p> : (
            sessions.length > 0 ? (
              <ul className="space-y-3">
                {sessions.map(session => (
                  <li key={session.id} className="p-3 border rounded-lg flex justify-between items-center">
                    <span>{session.name || session.id}</span>
                    <span className={`px-3 py-1 text-sm rounded-full ${session.status === 'CONNECTED' ? 'bg-green-200 text-green-800' : 'bg-yellow-200 text-yellow-800'}`}>
                      {session.status}
                    </span>
                  </li>
                ))}
              </ul>
            ) : <p>Nenhuma sessão conectada ainda.</p>
          )}
        </div>
      </div>
    </div>
  )
}
EOF
echo "  -> Frontend atualizado."
cd ..

echo ""
echo "--- ✅ SUCESSO! A nova arquitetura foi implementada. ---"
echo ""
echo "🚨 **PASSOS CRÍTICOS PARA VOCÊ EXECUTAR AGORA:**"
echo "1.  **Migrar o Banco de Dados:** A estrutura do banco mudou."
echo "    - Navegue até a pasta da API: \`cd api\`"
echo "    - Execute o comando de migração: \`npx prisma migrate dev --name add-robust-whatsapp-feature\`"
echo ""
echo "2.  **Reiniciar os Servidores:**"
echo "    - Inicie o backend na pasta 'api' com \`npm run dev\`."
echo "    - Inicie o frontend na pasta 'src' com \`npm run dev\`."
echo ""
echo "O sistema agora está pronto, com uma base sólida para futuras expansões."