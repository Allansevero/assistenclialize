import { Response } from 'express';
import { AuthRequest } from '../../middleware/auth.middleware';
import { inviteMemberService } from './teams.service';

export const inviteMemberController = async (req: AuthRequest, res: Response) => {
  try {
    const adminId = req.user!.userId;
    const newMember = await inviteMemberService(adminId, req.body);
    res.status(201).json(newMember);
  } catch (error) {
    res.status(400).json({ message: (error as Error).message });
  }
};
