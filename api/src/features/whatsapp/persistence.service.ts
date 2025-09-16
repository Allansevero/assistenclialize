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
