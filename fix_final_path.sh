#!/bin/bash

echo "--- CORRIGINDO O CAMINHO DO ARQUIVO DE CREDENCIAIS NA LÓGICA DE PERSISTÊNCIA ---"
cd api

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

  // CÓDIGO DE CONEXÃO ESTÁVEL - INTOCADO
  public async createSession(userId: string) {
    const sessionFolder = `auth_info_baileys/${userId}`;
    const { state, saveCreds } = await useMultiFileAuthState(sessionFolder);
    const sock = makeWASocket({ auth: state, printQRInTerminal: false });
    sock.ev.on('connection.update', (update) => {
      const { connection, lastDisconnect, qr } = update;
      if (qr) { this.io?.to(userId).emit('qr-code', qr); }
      if (connection === 'close') {
        const shouldReconnect = (lastDisconnect?.error as Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
        console.log(`[${userId}] Conexão fechada por:`, lastDisconnect?.error, ', reconectando:', shouldReconnect);
        if (shouldReconnect) { this.createSession(userId); }
      } else if (connection === 'open') {
        console.log(`[${userId}] Conexão aberta com sucesso!`);
        this.io?.to(userId).emit('session-ready', { message: 'Sessão conectada com sucesso!' });
      }
    });
    sock.ev.on('creds.update', saveCreds);
    sock.ev.on('messages.upsert', m => { console.log(`[${userId}] Nova mensagem:`, JSON.stringify(m, undefined, 2)); });
  }
  
  // FUNÇÃO DE PERSISTÊNCIA COM O CAMINHO CORRIGIDO
  public async persistSession(userId: string) {
    console.log(`[${userId}] [PERSIST] Iniciando persistência da sessão no banco de dados...`);
    const sessionFolder = `auth_info_baileys/${userId}`;
    try {
      // --- CORREÇÃO AQUI ---
      // O caminho agora é relativo à pasta raiz da API, onde o processo é executado.
      const credsFilePath = path.resolve(sessionFolder, 'creds.json');
      console.log(`[DEBUG] Lendo o arquivo de: ${credsFilePath}`);
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
      return { success: true };
    } catch (err) {
      console.error(`[${userId}] [PERSIST] Falha ao ler ou salvar credenciais no banco de dados:`, err);
      throw new Error('Failed to persist session');
    }
  }

  // Funções placeholder
  public async getChats(sessionId: string) { return []; }
  public async getMessages(sessionId: string, chatId: string) { return []; }
}
export const sessionManager = BaileysSessionManager.getInstance();
EOF
echo "  -> whatsapp.service.ts (Caminho de persistência corrigido!)"