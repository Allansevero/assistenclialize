// /api/src/features/whatsapp/whatsapp.service.ts

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
  private latestQrByUserId: Map<string, string> = new Map();
  private constructor() {}
  public static getInstance(): BaileysSessionManager { if (!this.instance) { this.instance = new BaileysSessionManager(); } return this.instance; }

  // =================================================================
  // CÓDIGO DE CONEXÃO ESTÁVEL - SEM NENHUMA ALTERAÇÃO
  // =================================================================
  public async createSession(userId: string, options?: { force?: boolean }) {
    const sessionFolder = `auth_info_baileys/${userId}`;
    if (options?.force) {
      try {
        await fs.rm(sessionFolder, { recursive: true, force: true });
      } catch {}
    }
    const { state, saveCreds } = await useMultiFileAuthState(sessionFolder);
    const sock = makeWASocket({ auth: state, printQRInTerminal: false });
    sock.ev.on('connection.update', (update) => {
      const { connection, lastDisconnect, qr } = update;
      if (qr) {
        this.latestQrByUserId.set(userId, qr);
        this.io?.to(userId).emit('qr-code', qr);
      }
      if (connection === 'close') {
        const shouldReconnect = (lastDisconnect?.error as Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
        console.log(`[${userId}] Conexão fechada por:`, lastDisconnect?.error, ', reconectando:', shouldReconnect);
        if (shouldReconnect) { this.createSession(userId); }
      } else if (connection === 'open') {
        console.log(`[${userId}] Conexão aberta com sucesso!`);
        this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!' });
        this.latestQrByUserId.delete(userId);
      }
    });
    sock.ev.on('creds.update', saveCreds);
  }
  
  // =================================================================
  // NOVA FUNÇÃO DE PERSISTÊNCIA - SEPARADA E COM CAMINHO CORRIGIDO
  // =================================================================
  public async persistSession(userId: string) {
    console.log(`[${userId}] [PERSIST] Iniciando persistência da sessão no banco de dados...`);
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
      console.log(`[${userId}] [PERSIST] Sessão salva/atualizada com sucesso no banco de dados!`);
    } catch (err) {
      console.error(`[${userId}] [PERSIST] Falha ao ler ou salvar credenciais no banco de dados:`, err);
      throw new Error('Failed to persist session');
    }
  }

  public async listSessions(userId: string) {
    return prisma.whatsappSession.findMany({
      where: { assignedToId: userId },
      select: { id: true, name: true, status: true },
      orderBy: { name: 'asc' },
    });
  }

  // Restaura sessões previamente persistidas no banco escrevendo o creds.json
  // e inicializando a conexão do Baileys para cada usuário.
  public async restoreAllSessions() {
    const sessions = await prisma.whatsappSession.findMany({
      where: { sessionData: { not: null } },
      select: { assignedToId: true, sessionData: true },
    });
    for (const s of sessions) {
      const userId = s.assignedToId as string | null;
      if (!userId) { continue; }
      const sessionFolder = path.resolve('auth_info_baileys', userId);
      try {
        await fs.mkdir(sessionFolder, { recursive: true });
        const credsFilePath = path.resolve(sessionFolder, 'creds.json');
        await fs.writeFile(credsFilePath, JSON.stringify(s.sessionData, null, 2), { encoding: 'utf-8' });
        // Inicializa a sessão
        await this.createSession(userId);
      } catch (err) {
        console.error(`[${userId}] Falha ao restaurar sessão:`, err);
      }
    }
  }

  public getLatestQr(userId: string): string | null {
    return this.latestQrByUserId.get(userId) ?? null;
  }
}
export const sessionManager = BaileysSessionManager.getInstance();