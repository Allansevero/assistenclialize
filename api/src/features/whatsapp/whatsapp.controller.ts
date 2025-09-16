import { Response } from 'express';
import { AuthRequest } from '../../middleware/auth.middleware';
import { connectionService } from './whatsapp.service';
import { persistenceService } from './persistence.service';

export const connectWhatsappController = (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user!.userId;
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
