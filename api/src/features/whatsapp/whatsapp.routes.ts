// /api/src/features/whatsapp/whatsapp.routes.ts

import { Router } from 'express';
import { protect } from '../../middleware/auth.middleware';
import { connectWhatsappController, persistSessionController, listSessionsController, latestQrController } from './whatsapp.controller';

const router = Router();
router.post('/sessions/connect', protect, connectWhatsappController);
router.post('/sessions/persist', protect, persistSessionController);
router.get('/sessions', protect, listSessionsController);
router.get('/sessions/latest-qr', protect, latestQrController);
export default router;