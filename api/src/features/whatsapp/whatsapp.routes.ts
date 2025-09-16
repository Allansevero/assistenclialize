import { Router } from 'express';
import { protect } from '../../middleware/auth.middleware';
import { connectWhatsappController } from './whatsapp.controller';

const router = Router();
router.post('/sessions/connect', protect, connectWhatsappController);
export default router;
