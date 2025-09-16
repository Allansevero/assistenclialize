#!/bin/bash

echo "--- Iniciando setup da funcionalidade de Equipes (Teams) ---"

# --- Passo 1: Criar a estrutura de pastas ---
echo "[1/3] Criando estrutura de pastas para middleware e teams..."
mkdir -p src/middleware
mkdir -p src/features/teams
echo "Estrutura de pastas criada."
echo ""

# --- Passo 2: Gerar arquivos de código ---
echo "[2/3] Gerando arquivos de código..."

# 2.1 - auth.middleware.ts
cat << 'EOF' > src/middleware/auth.middleware.ts
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
EOF
echo "  -> src/middleware/auth.middleware.ts (OK)"

# 2.2 - teams.service.ts (Lógica simplificada para MVP)
cat << 'EOF' > src/features/teams/teams.service.ts
import { PrismaClient } from '@prisma/client';
import { z } from 'zod';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const InviteSchema = z.object({
  email: z.string().email(),
  name: z.string().min(3),
});

export const inviteMemberService = async (adminId: string, body: unknown) => {
  const data = InviteSchema.parse(body);
  
  // Encontrar o time do admin que está fazendo o convite
  const adminUser = await prisma.user.findUnique({ where: { id: adminId }});
  if (!adminUser || !adminUser.teamId) {
    throw new Error('Admin or team not found.');
  }

  // Verificar se o email já está em uso
  const existingUser = await prisma.user.findUnique({ where: { email: data.email }});
  if (existingUser) {
    throw new Error('Email is already in use.');
  }

  // Cria um novo usuário (MEMBER) com uma senha temporária aleatória
  const tempPassword = Math.random().toString(36).slice(-8);
  const hashedPassword = await bcrypt.hash(tempPassword, 10);

  const newMember = await prisma.user.create({
    data: {
      email: data.email,
      name: data.name,
      password: hashedPassword, // O usuário precisará resetar isso no primeiro login
      role: 'MEMBER',
      teamId: adminUser.teamId,
    }
  });

  const { password, ...memberWithoutPassword } = newMember;
  return memberWithoutPassword;
};
EOF
echo "  -> src/features/teams/teams.service.ts (OK)"

# 2.3 - teams.controller.ts
cat << 'EOF' > src/features/teams/teams.controller.ts
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
EOF
echo "  -> src/features/teams/teams.controller.ts (OK)"

# 2.4 - teams.routes.ts
cat << 'EOF' > src/features/teams/teams.routes.ts
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
EOF
echo "  -> src/features/teams/teams.routes.ts (OK)"

# --- Passo 3: Atualizar o servidor para usar as novas rotas ---
echo "[3/3] Atualizando o arquivo do servidor (server.ts)..."
cat << 'EOF' > src/server.ts
import express from 'express';
import authRoutes from './features/auth/auth.routes';
import teamRoutes from './features/teams/teams.routes'; // Importa as novas rotas

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/api', (req, res) => {
  res.send('Assistenclialize API is running!');
});

// Rotas da API
app.use('/api/auth', authRoutes);
app.use('/api/teams', teamRoutes); // Usa as novas rotas de equipe

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
EOF
echo "  -> src/server.ts (OK)"
echo ""
echo "--- Setup concluído com sucesso! ---"
echo "O servidor irá reiniciar. Agora você pode testar a nova rota."