import express from 'express';
import cors from 'cors';
import http from 'http';
import { Server as SocketIOServer } from 'socket.io';

import authRoutes from './features/auth/auth.routes';
import teamRoutes from './features/teams/teams.routes';
import whatsappRoutes from './features/whatsapp/whatsapp.routes';
import { sessionManager } from './features/whatsapp/whatsapp.service';

const app = express();
const server = http.createServer(app);

const corsOptions = {
  origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    console.log('CORS check for origin:', origin);
    callback(null, true);
  },
};

const io = new SocketIOServer(server, { cors: corsOptions });

sessionManager.io = io;

const PORT = process.env.PORT || 3000;

app.use(cors(corsOptions));
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/teams', teamRoutes);
app.use('/api/whatsapp', whatsappRoutes);

io.on('connection', (socket) => {
  console.log(`[Socket.IO] Novo cliente conectado: ${socket.id}`);
  socket.on('join-room', (userId) => {
    console.log(`[Socket.IO] Cliente ${socket.id} entrou na sala ${userId}`);
    socket.join(userId);
  });
  socket.on('disconnect', () => {
    console.log(`[Socket.IO] Cliente desconectado: ${socket.id}`);
  });
});

// A chamada para a função antiga foi REMOVIDA daqui.
server.listen(PORT, '0.0.0.0', () => {
  console.log(`�� Servidor rodando em http://localhost:${PORT} e acessível na rede local`);
  // A inicialização a partir do DB será reimplementada depois, de forma compatível com o Baileys.
});
