import makeWASocket, {
  DisconnectReason,
  fetchLatestBaileysVersion,
  jidNormalizedUser,
  useMultiFileAuthState,
} from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import { PrismaClient } from '@prisma/client';
import pino from 'pino';
import fs from 'fs/promises';
import path from 'path';
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

        const sessionDir = `auth_info_baileys/session-${sessionId}`;
        const credsFile = path.join(sessionDir, 'creds.json');

        try {
            const sessionFromDb = await prisma.whatsappSession.findUnique({ where: { id: sessionId } });
            if (sessionFromDb?.sessionData) {
                await fs.mkdir(sessionDir, { recursive: true });
                await fs.writeFile(credsFile, JSON.stringify(sessionFromDb.sessionData));
                logger.info(`[${sessionId}] Sessão restaurada do DB para o arquivo.`);
            }
        } catch (e) {
            logger.error(e, `[${sessionId}] Falha ao restaurar sessão do DB.`);
        }

        const { state, saveCreds } = await useMultiFileAuthState(sessionDir);
        const { version } = await fetchLatestBaileysVersion();
        
        const sock = makeWASocket({ version, auth: state, printQRInTerminal: false, logger });
        this.clients.set(sessionId, sock);

        sock.ev.on('creds.update', async () => {
            await saveCreds();
            try {
                const creds = await fs.readFile(credsFile, { encoding: 'utf-8' });
                await prisma.whatsappSession.update({
                    where: { id: sessionId },
                    data: { sessionData: JSON.parse(creds) },
                });
                logger.info(`[${sessionId}] Credenciais sincronizadas para o DB.`);
            } catch (e) {
                logger.error(e, `[${sessionId}] Falha ao sincronizar credenciais para o DB.`);
            }
        });

        sock.ev.on('connection.update', async (update) => {
            const { connection, lastDisconnect, qr } = update;
            if (qr) {
                socketManager.emitToUser(userId, 'qr-code', { sessionId, qr });
                await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'AWAITING_QR' } });
            }
            if (connection === 'close') {
                const statusCode = (lastDisconnect?.error as Boom)?.output?.statusCode;
                this.clients.delete(sessionId);
                if (statusCode !== DisconnectReason.loggedOut) {
                    this.initializeSocket(sessionId, userId);
                } else {
                    await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'DISCONNECTED', sessionData: null } });
                    await fs.rm(sessionDir, { recursive: true, force: true });
                }
            } else if (connection === 'open') {
                await prisma.whatsappSession.update({ where: { id: sessionId }, data: { status: 'CONNECTED' } });
                socketManager.emitToUser(userId, 'session-status', { sessionId, status: 'CONNECTED' });
            }
        });
    }

    public async restoreAllSessions() {
        logger.info('[SessionManager] Restaurando todas as sessões do banco de dados...');
        const sessions = await prisma.whatsappSession.findMany({
            where: { OR: [{status: 'CONNECTED'}, {status: 'AWAITING_QR'}] }
        });
        logger.info(`[SessionManager] ${sessions.length} sessões encontradas para restaurar.`);
        for (const session of sessions) {
            this.initializeSocket(session.id, session.assignedToId);
        }
    }
}

export const sessionManager = SessionManager.getInstance();
