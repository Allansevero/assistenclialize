#!/bin/bash

echo "--- OPERAÇÃO FÊNIX | ETAPA 2: A FUNDAÇÃO ---"
echo "Recriando a lógica de autenticação, páginas e roteamento."
echo ""

# Navega para a pasta do frontend
cd src

# --- TAREFA 1: Criar a estrutura de pastas ---
echo "[1/4] Criando a estrutura de diretórios..."
mkdir -p src/lib
mkdir -p src/stores
mkdir -p src/pages
echo "  -> Estrutura 'lib', 'stores', e 'pages' criada."
echo ""

# --- TAREFA 2: Criar os arquivos de lógica ---
echo "[2/4] Criando os arquivos de lógica (api.ts, auth.store.ts)..."

# api.ts
cat << 'EOF' > src/lib/api.ts
import axios from 'axios';
export const api = axios.create({ baseURL: 'http://localhost:3000/api' });
EOF

# auth.store.ts
cat << 'EOF' > src/stores/auth.store.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface User { id: string; name: string; email: string; role: 'ADMIN' | 'MEMBER'; }
interface AuthState {
  token: string | null;
  user: User | null;
  login: (token: string, user: User) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      token: null, user: null,
      login: (token, user) => set({ token, user }),
      logout: () => {
        set({ token: null, user: null });
        localStorage.removeItem('auth-storage');
      }
    }),
    { name: 'auth-storage' }
  )
);
EOF
echo "  -> Arquivos de lógica criados."
echo ""

# --- TAREFA 3: Criar as Páginas ---
echo "[3/4] Criando as páginas (Login, Register, Dashboard)..."

# LoginPage.tsx
cat << 'EOF' > src/pages/LoginPage.tsx
import { useForm } from 'react-hook-form';
import { Link, useNavigate } from 'react-router-dom';
import { z } from 'zod';
import { zodResolver } from '@hookform/resolvers/zod';
import { api } from '../lib/api';
import toast from 'react-hot-toast';
import { useAuthStore } from '../stores/auth.store';
import { jwtDecode } from "jwt-decode";

const loginFormSchema = z.object({
  email: z.string().email({ message: 'Por favor, insira um email válido.' }),
  password: z.string().min(1, { message: 'Por favor, insira sua senha.' }),
});
type LoginFormData = z.infer<typeof loginFormSchema>;
interface UserPayload { userId: string; name: string; role: 'ADMIN' | 'MEMBER'; }

export function LoginPage() {
  const navigate = useNavigate();
  const { login } = useAuthStore();
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<LoginFormData>({ resolver: zodResolver(loginFormSchema) });

  async function handleLogin(data: LoginFormData) {
    try {
      const response = await api.post('/auth/login', data);
      const { token } = response.data;
      const decodedToken = jwtDecode<UserPayload>(token);
      const user = { id: decodedToken.userId, name: decodedToken.name, email: data.email, role: decodedToken.role };
      login(token, user);
      toast.success('Login bem-sucedido!');
      navigate('/dashboard');
    } catch (error) {
      toast.error('Credenciais inválidas.');
    }
  }

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-100">
      <div className="w-full max-w-md p-8 space-y-6 bg-white rounded-lg shadow-md">
        <h2 className="text-2xl font-bold text-center">Entrar na sua Conta</h2>
        <form onSubmit={handleSubmit(handleLogin)} className="space-y-4">
          <div><label htmlFor="email" className="block text-sm font-medium text-gray-700">Email</label><input id="email" type="email" {...register('email')} className="w-full px-3 py-2 mt-1 border rounded-md" />{errors.email && <span className="text-red-500 text-sm">{errors.email.message}</span>}</div>
          <div><label htmlFor="password"  className="block text-sm font-medium text-gray-700">Senha</label><input id="password" type="password" {...register('password')} className="w-full px-3 py-2 mt-1 border rounded-md" />{errors.password && <span className="text-red-500 text-sm">{errors.password.message}</span>}</div>
          <div><button type="submit" disabled={isSubmitting} className="w-full px-4 py-2 font-bold text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:bg-blue-300">{isSubmitting ? 'Entrando...' : 'Entrar'}</button></div>
        </form>
        <p className="text-sm text-center text-gray-600">Não tem uma conta?{' '}<Link to="/register" className="font-medium text-blue-600 hover:text-blue-500">Cadastre-se</Link></p>
      </div>
    </div>
  );
}
EOF

# RegisterPage.tsx
cat << 'EOF' > src/pages/RegisterPage.tsx
import { useForm } from 'react-hook-form';
import { Link, useNavigate } from 'react-router-dom';
import { z } from 'zod';
import { zodResolver } from '@hookform/resolvers/zod';
import { api } from '../lib/api';
import toast from 'react-hot-toast';

const registerFormSchema = z.object({
  name: z.string().min(3, { message: 'O nome precisa ter no mínimo 3 caracteres.' }),
  email: z.string().email({ message: 'Por favor, insira um email válido.' }),
  password: z.string().min(6, { message: 'A senha precisa ter no mínimo 6 caracteres.' }),
});
type RegisterFormData = z.infer<typeof registerFormSchema>;

export function RegisterPage() {
  const navigate = useNavigate();
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<RegisterFormData>({
    resolver: zodResolver(registerFormSchema),
  });

  async function handleRegister(data: RegisterFormData) {
    try {
      await api.post('/auth/register', data);
      toast.success('Conta criada com sucesso! Redirecionando para o login...');
      setTimeout(() => navigate('/login'), 2000);
    } catch (error) {
      toast.error('Não foi possível criar a conta. Verifique os dados ou tente outro email.');
    }
  }

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-100">
      <div className="w-full max-w-md p-8 space-y-6 bg-white rounded-lg shadow-md">
        <h2 className="text-2xl font-bold text-center">Criar sua Conta</h2>
        <form onSubmit={handleSubmit(handleRegister)} className="space-y-4">
          <div><label htmlFor="name" className="block text-sm font-medium text-gray-700">Nome</label><input id="name" type="text" {...register('name')} className="w-full px-3 py-2 mt-1 border rounded-md" />{errors.name && <span className="text-red-500 text-sm">{errors.name.message}</span>}</div>
          <div><label htmlFor="email" className="block text-sm font-medium text-gray-700">Email</label><input id="email" type="email" {...register('email')} className="w-full px-3 py-2 mt-1 border rounded-md" />{errors.email && <span className="text-red-500 text-sm">{errors.email.message}</span>}</div>
          <div><label htmlFor="password" className="block text-sm font-medium text-gray-700">Senha</label><input id="password" type="password" {...register('password')} className="w-full px-3 py-2 mt-1 border rounded-md" />{errors.password && <span className="text-red-500 text-sm">{errors.password.message}</span>}</div>
          <div><button type="submit" disabled={isSubmitting} className="w-full px-4 py-2 font-bold text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:bg-blue-300">{isSubmitting ? 'Registrando...' : 'Registrar'}</button></div>
        </form>
        <p className="text-sm text-center text-gray-600">Já tem uma conta?{' '}<Link to="/login" className="font-medium text-blue-600 hover:text-blue-500">Faça Login</Link></p>
      </div>
    </div>
  );
}
EOF

# DashboardPage.tsx
cat << 'EOF' > src/pages/DashboardPage.tsx
import { useAuthStore } from "../stores/auth.store";
import { useNavigate } from "react-router-dom";

export function DashboardPage() {
  const { user, logout } = useAuthStore();
  const navigate = useNavigate();

  function handleLogout() {
    logout();
    navigate('/login');
  }
  
  return (
    <div className="p-8">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">Bem-vindo ao Dashboard, {user?.name}!</h1>
        <button onClick={handleLogout} className="px-4 py-2 text-white bg-red-600 rounded hover:bg-red-700">Sair</button>
      </div>
      <p className="mt-4">Esta é uma área protegida. A fundação está pronta!</p>
    </div>
  );
}
EOF
echo "  -> Páginas criadas."
echo ""


# --- TAREFA 4: Criar o Roteador Principal ---
echo "[4/4] Criando o roteador principal (App.tsx)..."

# App.tsx
cat << 'EOF' > src/App.tsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { useAuthStore } from './stores/auth.store';
import { LoginPage } from './pages/LoginPage';
import { RegisterPage } from './pages/RegisterPage';
import { DashboardPage } from './pages/DashboardPage';

const ProtectedRoute = ({ children }: { children: React.ReactNode }) => {
  const { token } = useAuthStore();
  if (!token) {
    return <Navigate to="/login" />;
  }
  return children;
};

function App() {
  return (
    <BrowserRouter>
      <Toaster position="top-right" />
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/register" element={<RegisterPage />} />
        <Route path="/dashboard" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
        <Route path="/" element={<Navigate to="/dashboard" />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
EOF

# Limpa o App.css padrão
echo "" > src/App.css

echo "  -> Roteador criado."
echo ""

cd ..
echo "--- ✅ SUCESSO! Etapa 2 concluída. ---"
echo "A fundação do seu app (login, registro e rotas) foi reconstruída."
echo "Execute 'npm run dev' na pasta 'src' e teste o fluxo de autenticação!"
echo "Quando estiver pronto, passaremos para a Etapa 3 para conectar o WhatsApp."