import { Response } from 'express';
import { AuthRequest } from '../../middleware/auth.middleware';
import { PrismaClient } from '@prisma/client';
import { connectionService } from './whatsapp.service'; // NOME CORRIGIDO AQUI
import { persistenceService } from './persistence.service';

const prisma = new PrismaClient();

export const connectWhatsappController = (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user!.userId;
        // Chama o serviço pelo nome correto
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

export const listSessionsController = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user!.userId;
        const sessions = await prisma.whatsappSession.findMany({ where: { assignedToId: userId }, select: { id: true, name: true, status: true } });
        res.status(200).json(sessions);
    } catch (error) {
        res.status(500).json({ message: 'Erro ao listar sessões.' });
    }
};
