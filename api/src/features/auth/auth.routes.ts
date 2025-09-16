import { Router } from 'express';
import { registerAdminController, loginController } from './auth.controller';

const router = Router();

router.post('/register', registerAdminController);

// --- NOVA ROTA DE LOGIN ---
router.post('/login', loginController);

export default router;