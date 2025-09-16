import { Router } from 'express';
import { protect } from '../../middleware/auth.middleware';
import { connectNewSessionController } from './whatsapp.controller';

const router = Router();
router.post('/sessions/connect', protect, connectNewSessionController);

export default router;
