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
