import { Response } from 'express';
import { AuthRequest } from '../../middleware/auth.middleware';
import { sessionManager } from './whatsapp.service';

export const connectNewSessionController = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user!.userId;
        const session = await sessionManager.startNewSession(userId);
        res.status(201).json({ message: 'Processo de conexão iniciado.', session });
    } catch (error) {
        res.status(500).json({ message: 'Erro ao iniciar a sessão.' });
    }
};
