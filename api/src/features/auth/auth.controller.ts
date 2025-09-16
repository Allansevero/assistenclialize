import { Request, Response } from 'express';
import { registerAdminService, loginService } from './auth.service';

export const registerAdminController = async (req: Request, res: Response) => {
  try {
    const newUser = await registerAdminService(req.body);
    res.status(201).json(newUser);
  } catch (error) {
    res.status(400).json({ message: (error as Error).message });
  }
};

// --- NOVO CONTROLLER DE LOGIN ---
export const loginController = async (req: Request, res: Response) => {
    try {
        const result = await loginService(req.body);
        res.status(200).json(result);
    } catch (error) {
        res.status(401).json({ message: (error as Error).message });
    }
};