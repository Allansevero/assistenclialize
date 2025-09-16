#!/bin/bash

echo "--- Iniciando a Criação do Serviço de Gerenciamento de Sessões WhatsApp ---"
echo ""

# Navega para a pasta do backend
cd api

# --- Passo 1: Instalar Novas Dependências ---
echo "[1/4] Instalando whatsapp-web.js e socket.io..."
# A 'puppeteer' é uma dependência pesada que o whatsapp-web.js usa por baixo dos panos
npm install whatsapp-web.js@latest socket.io puppeteer
echo "Dependências instaladas com sucesso."
echo ""

# --- Passo 2: Criar a Estrutura de Arquivos ---
echo "[2/4] Criando a estrutura de arquivos para a funcionalidade 'whatsapp'..."
mkdir -p src/features/whatsapp
echo "Estrutura de arquivos criada."
echo ""

# --- Passo 3: Criar os Arquivos da Funcionalidade ---
echo "[3/4] Gerando os arquivos de código para o serviço de WhatsApp..."

# 3.1 - whatsapp.service.ts (O Cérebro)
cat << 'EOF' > src/features/whatsapp/whatsapp.service.ts
import { Client, LocalAuth } from 'whatsapp-web.js';
import { Server as SocketIOServer } from 'socket.io';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Esta classe irá gerenciar todas as instâncias ativas do cliente WhatsApp
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
  
  // Método para inicializar uma nova sessão para um usuário
  public createSession(userId: string) {
    console.log(`[SessionManager] Criando nova sessão para o usuário: ${userId}`);
    
    // ID da sessão será o mesmo ID do usuário por simplicidade no MVP
    const sessionId = userId;

    const client = new Client({
      authStrategy: new LocalAuth({ clientId: sessionId }),
      puppeteer: {
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      }
    });

    client.on('qr', (qr) => {
      console.log(`[${sessionId}] QR Code recebido. Enviando para o frontend...`);
      // Emite o QR Code para o frontend através do socket
      this.io?.to(userId).emit('qr-code', qr);
    });

    client.on('ready', () => {
      console.log(`[${sessionId}] Cliente está pronto!`);
      this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!' });
      // Aqui, no futuro, salvaremos a sessão no banco
    });
    
    client.on('authenticated', (session) => {
      console.log(`[${sessionId}] Autenticado!`);
      // AQUI É ONDE SALVAREMOS A SESSÃO NO BANCO DE DADOS
      // Por enquanto, apenas logamos a informação.
      // A lógica de salvar no DB virá no próximo passo.
    });

    client.on('auth_failure', (msg) => {
      console.error(`[${sessionId}] Falha na autenticação:`, msg);
      this.io?.to(userId).emit('auth-failure', { message: 'Falha na autenticação.' });
    });

    client.on('disconnected', (reason) => {
      console.log(`[${sessionId}] Cliente foi desconectado:`, reason);
      this.clients.delete(sessionId);
    });

    client.initialize();
    this.clients.set(sessionId, client);
  }
}

export const sessionManager = SessionManager.getInstance();
EOF
echo "  -> whatsapp.service.ts (Criado)"

# 3.2 - whatsapp.controller.ts
cat << 'EOF' > src/features/whatsapp/whatsapp.controller.ts
import { Response } from 'express';
import { AuthRequest } from '../../middleware/auth.middleware';
import { sessionManager } from './whatsapp.service';

export const connectWhatsappController = (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    sessionManager.createSession(userId);
    res.status(200).json({ message: 'Processo de conexão iniciado. Verifique o QR Code no seu frontend.' });
  } catch (error) {
    res.status(500).json({ message: 'Erro ao iniciar a sessão do WhatsApp.' });
  }
};
EOF
echo "  -> whatsapp.controller.ts (Criado)"

# 3.3 - whatsapp.routes.ts
cat << 'EOF' > src/features/whatsapp/whatsapp.routes.ts
import { Router } from 'express';
import { protect } from '../../middleware/auth.middleware';
import { connectWhatsappController } from './whatsapp.controller';

const router = Router();

// Endpoint protegido para iniciar uma nova conexão
router.post('/sessions/connect', protect, connectWhatsappController);

export default router;
EOF
echo "  -> whatsapp.routes.ts (Criado)"
echo ""

# --- Passo 4: Atualizar o Servidor para usar WebSockets ---
echo "[4/4] Atualizando o arquivo src/server.ts para integrar o Socket.IO..."
cat << 'EOF' > src/server.ts
import express from 'express';
import cors from 'cors';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';

// Importa nossas rotas e serviços
import authRoutes from './features/auth/auth.routes';
import teamRoutes from './features/teams/teams.routes';
import whatsappRoutes from './features/whatsapp/whatsapp.routes';
import { sessionManager } from './features/whatsapp/whatsapp.service';

const app = express();
const server = http.createServer(app);

// Configuração do Socket.IO
const io = new SocketIOServer(server, {
  cors: {
    origin: "http://localhost:5173", // Permite a conexão do nosso frontend
    methods: ["GET", "POST"]
  }
});

// Passa a instância do 'io' para o nosso SessionManager
sessionManager.io = io;

const PORT = process.env.PORT || 3000;

app.use(cors({ origin: 'http://localhost:5173' }));
app.use(express.json());

// Rotas da API
app.use('/api/auth', authRoutes);
app.use('/api/teams', teamRoutes);
app.use('/api/whatsapp', whatsappRoutes);

// Lógica de Conexão do Socket
io.on('connection', (socket) => {
  console.log(`[Socket.IO] Novo cliente conectado: ${socket.id}`);
  
  // Quando um cliente se conecta, ele deve se juntar a uma "sala"
  // com seu próprio ID de usuário para receber eventos privados.
  // O frontend precisará emitir um evento 'join-room' com o userId.
  socket.on('join-room', (userId) => {
    console.log(`[Socket.IO] Cliente ${socket.id} entrou na sala ${userId}`);
    socket.join(userId);
  });

  socket.on('disconnect', () => {
    console.log(`[Socket.IO] Cliente desconectado: ${socket.id}`);
  });
});

// Usamos 'server.listen' em vez de 'app.listen' para o Socket.IO funcionar
server.listen(PORT, () => {
  console.log(`🚀 Servidor rodando em http://localhost:${PORT}`);
});
EOF
echo "  -> src/server.ts (Atualizado com Socket.IO!)"
echo ""

echo "--- SUCESSO! O backend agora está pronto para gerenciar sessões do WhatsApp. ---"
echo "O próximo passo será criar a interface no frontend para exibir o QR Code."