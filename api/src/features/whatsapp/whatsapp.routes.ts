// /api/src/features/whatsapp/whatsapp.routes.ts

import { Router } from 'express';
import { protect } from '../../middleware/auth.middleware';
import * as ctrl from './whatsapp.controller';

const router = Router();
router.get('/ping', (_req, res) => res.status(200).json({ ok: true }));
router.post('/sessions/connect', protect, ctrl.connectWhatsappController);
router.post('/sessions/persist', protect, ctrl.persistSessionController);
router.get('/sessions', protect, ctrl.listSessionsController);
router.get('/sessions/latest-qr', protect, ctrl.latestQrController);
export default router;