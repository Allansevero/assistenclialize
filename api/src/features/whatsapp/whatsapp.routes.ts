// /api/src/features/whatsapp/whatsapp.routes.ts

import { Router } from 'express';
import { protect } from '../../middleware/auth.middleware';
import { connectWhatsappController, persistSessionController, listSessionsController, latestQrController } from './whatsapp.controller';

const router = Router();
router.get('/ping', (_req, res) => res.status(200).json({ ok: true }));
router.post('/sessions/connect', protect, connectWhatsappController);
router.post('/sessions/persist', protect, persistSessionController);
router.get('/sessions', protect, listSessionsController);
router.get('/sessions/latest-qr', protect, latestQrController);
export default router;