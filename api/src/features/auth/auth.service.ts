import { PrismaClient } from '@prisma/client';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

const prisma = new PrismaClient();

// Esquema de Validação para Registro
const RegisterSchema = z.object({
  name: z.string().min(3),
  email: z.string().email(),
  password: z.string().min(6),
});

// Esquema de Validação para Login
const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
});

// -- FUNÇÃO DE REGISTRO (EXISTENTE) --
export const registerAdminService = async (body: unknown) => {
  const data = RegisterSchema.parse(body);
  const existingUser = await prisma.user.findUnique({ where: { email: data.email } });
  if (existingUser) {
    throw new Error('Email already in use');
  }
  const hashedPassword = await bcrypt.hash(data.password, 10);
  const newUser = await prisma.$transaction(async (tx) => {
    const user = await tx.user.create({
      data: {
        email: data.email,
        name: data.name,
        password: hashedPassword,
        role: 'ADMIN',
      },
    });
    const team = await tx.team.create({
      data: { name: `${data.name}'s Team`, ownerId: user.id },
    });
    return await tx.user.update({
      where: { id: user.id },
      data: { teamId: team.id },
    });
  });
  const { password, ...userWithoutPassword } = newUser;
  return userWithoutPassword;
};


// --- NOVA FUNÇÃO DE LOGIN ---
export const loginService = async (body: unknown) => {
  // 1. Validar os dados de entrada
  const data = LoginSchema.parse(body);

  // 2. Encontrar o usuário pelo email
  const user = await prisma.user.findUnique({
    where: { email: data.email },
  });
  if (!user) {
    throw new Error('Invalid credentials');
  }

  // 3. Comparar a senha fornecida com a senha criptografada no banco
  const isPasswordValid = await bcrypt.compare(data.password, user.password);
  if (!isPasswordValid) {
    throw new Error('Invalid credentials');
  }

  // 4. Gerar o token JWT
  const token = jwt.sign(
    { userId: user.id, role: user.role },
    process.env.JWT_SECRET as string,
    { expiresIn: '7d' } // Token expira em 7 dias
  );

  // 5. Retornar o token
  return { token };
};