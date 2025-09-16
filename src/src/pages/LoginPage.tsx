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
