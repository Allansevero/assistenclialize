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

socketManager.initialize(server);
// Garante que o gerenciador de sessões possa emitir eventos via Socket.IO
sessionManager.io = socketManager.io;

const PORT = process.env.PORT || 3000;
app.use(cors({ origin: '*' }));
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/teams', teamRoutes);
app.use('/api/whatsapp', whatsappRoutes);

// Healthcheck simples
app.get('/api/health', (_req, res) => res.status(200).json({ ok: true }));

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor rodando em http://localhost:${PORT}`);
  sessionManager.restoreAllSessions();
});
