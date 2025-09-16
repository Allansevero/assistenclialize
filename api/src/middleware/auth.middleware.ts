import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

// Estendendo a interface Request do Express para incluir nossa propriedade 'user'
export interface AuthRequest extends Request {
  user?: { userId: string; role: string };
}

export const protect = (req: AuthRequest, res: Response, next: NextFunction) => {
  const bearer = req.headers.authorization;

  if (!bearer || !bearer.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'No token provided' });
  }

  const [, token] = bearer.split(' ');

  if (!token) {
    return res.status(401).json({ message: 'Invalid token format' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET as string) as { userId: string; role: string };
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ message: 'Invalid token' });
  }
};

export const isAdmin = (req: AuthRequest, res: Response, next: NextFunction) => {
    if (req.user?.role !== 'ADMIN') {
        return res.status(403).json({ message: 'Forbidden: Admins only' });
    }
    next();
};
