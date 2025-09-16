import { Router } from 'express';
import { protect } from '../../middleware/auth.middleware';
import { connectWhatsappController, persistSessionController } from './whatsapp.controller';

const router = Router();
router.post('/sessions/connect', protect, connectWhatsappController);
router.post('/sessions/persist', protect, persistSessionController);
export default router;
