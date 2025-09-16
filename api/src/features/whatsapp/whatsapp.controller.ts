// /api/src/features/whatsapp/whatsapp.controller.ts

import { Response } from 'express';
import { AuthRequest } from '../../middleware/auth.middleware';
import { sessionManager } from './whatsapp.service';

export const connectWhatsappController = (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user!.userId;
        sessionManager.createSession(userId);
        res.status(200).json({ message: 'Processo de conexão iniciado.' });
    } catch (error) {
        res.status(500).json({ message: 'Erro ao iniciar a sessão.' });
    }
};

export const persistSessionController = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user!.userId;
        await sessionManager.persistSession(userId);
        res.status(200).json({ message: 'Sessão persistida com sucesso.'});
    } catch (error) {
        res.status(500).json({ message: 'Erro ao persistir a sessão.'});
    }
};

export const listSessionsController = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const sessions = await sessionManager.listSessions(userId);
    res.status(200).json({ sessions });
  } catch (error) {
    res.status(500).json({ message: 'Erro ao listar sessões.' });
  }
};