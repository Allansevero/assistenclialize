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
