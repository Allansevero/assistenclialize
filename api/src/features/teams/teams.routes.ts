import { Router } from 'express';
import { inviteMemberController } from './teams.controller';
import { protect, isAdmin } from '../../middleware/auth.middleware';

const router = Router();

// A rota de convite agora é protegida!
// 1. `protect` verifica se o token é válido.
// 2. `isAdmin` verifica se o usuário é um Admin.
// Só então a função do controller é executada.
router.post('/invite', protect, isAdmin, inviteMemberController);

export default router;
