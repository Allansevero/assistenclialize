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
