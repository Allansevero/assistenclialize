#!/bin/bash

echo "--- OPERAÇÃO FÊNIX | ETAPA 3: O NÚCLEO (CONEXÃO WHATSAPP) ---"
echo "Recriando a página de conexão e integrando-a ao Dashboard."
echo ""

# Navega para a pasta do frontend
cd src

# --- TAREFA 1: Criar a Página de Conexão do WhatsApp ---
echo "[1/3] Criando a página 'ConnectWhatsAppPage.tsx'..."
cat << 'EOF' > src/pages/ConnectWhatsAppPage.tsx
import { useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import QRCode from 'react-qr-code';
import toast from 'react-hot-toast';
import { Link } from 'react-router-dom';
import { useAuthStore } from '../stores/auth.store';
import { api } from '../lib/api';

let socket: Socket;

export function ConnectWhatsAppPage() {
    const { user, token } = useAuthStore();
    const [qrCode, setQrCode] = useState<string | null>(null);
    const [status, setStatus] = useState('Ocioso');

    useEffect(() => {
        socket = io('http://localhost:3000');
        if (user) {
            socket.emit('join-room', user.id);
        }

        socket.on('qr-code', (data: { qr: string }) => {
            setQrCode(data.qr);
            setStatus('Aguardando escaneamento...');
        });

        socket.on('session-status', (data: { status: string }) => {
            if (data.status === 'CONNECTED') {
                toast.success('Sessão conectada com sucesso!');
                setStatus('Conectado!');
                setQrCode(null);
            }
        });

        return () => { socket.disconnect(); };
    }, [user]);

    async function handleStartConnection() {
        setStatus('Iniciando conexão...');
        setQrCode(null); // Limpa QR code antigo
        try {
            await api.post('/whatsapp/sessions/connect', {}, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setStatus('Aguardando QR Code do servidor...');
        } catch (error) {
            toast.error('Não foi possível iniciar a conexão.');
            setStatus('Erro ao iniciar.');
        }
    }

    return (
        <div className="p-8 max-w-lg mx-auto">
            <Link to="/dashboard" className="text-blue-600 hover:underline">&larr; Voltar para o Dashboard</Link>
            <div className="mt-4 p-6 border rounded-lg bg-white shadow-sm">
                <h1 className="text-2xl font-bold mb-4">Conectar Nova Conta</h1>
                <div className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
                    <p className="text-sm font-medium text-gray-700">Status: <span className="font-bold">{status}</span></p>
                    <button 
                        onClick={handleStartConnection} 
                        disabled={status !== 'Ocioso' && status !== 'Erro ao iniciar.'}
                        className="px-4 py-2 font-bold text-white bg-green-600 rounded-md hover:bg-green-700 disabled:bg-gray-400">
                        Gerar QR Code
                    </button>
                </div>
                {qrCode && (
                    <div className="mt-6 flex flex-col items-center">
                        <p className="mb-2 text-gray-600">Escaneie o QR Code com seu celular:</p>
                        <div className="p-4 bg-white border rounded-md">
                            <QRCode value={qrCode} size={256} />
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
EOF
echo "  -> Página de conexão criada."
echo ""

# --- TAREFA 2: Adicionar a Rota no App.tsx ---
echo "[2/3] Adicionando a rota '/connect-whatsapp' em 'App.tsx'..."
cat << 'EOF' > src/App.tsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { useAuthStore } from './stores/auth.store';
import { LoginPage } from './pages/LoginPage';
import { RegisterPage } from './pages/RegisterPage';
import { DashboardPage } from './pages/DashboardPage';
import { ConnectWhatsAppPage } from './pages/ConnectWhatsAppPage'; // Importa a nova página

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
        <Route path="/connect-whatsapp" element={<ProtectedRoute><ConnectWhatsAppPage /></ProtectedRoute>} /> 
        <Route path="/" element={<Navigate to="/dashboard" />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
EOF
echo "  -> Rota adicionada."
echo ""

# --- TAREFA 3: Adicionar o Link no Dashboard ---
echo "[3/3] Adicionando o link para a nova página no 'DashboardPage.tsx'..."
cat << 'EOF' > src/pages/DashboardPage.tsx
import { useAuthStore } from "../stores/auth.store";
import { Link, useNavigate } from "react-router-dom";

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
        <h1 className="text-2xl font-bold">Bem-vindo, {user?.name}!</h1>
        <div>
          <Link to="/connect-whatsapp">
            <button className="mr-4 px-4 py-2 font-bold text-white bg-green-600 rounded-md hover:bg-green-700">
              Conectar WhatsApp
            </button>
          </Link>
          <button onClick={handleLogout} className="px-4 py-2 text-white bg-red-600 rounded hover:bg-red-700">Sair</button>
        </div>
      </div>
      <div className="mt-8 p-6 border rounded-lg bg-white shadow-sm">
        <h2 className="text-xl font-semibold">Suas Sessões</h2>
        <p className="mt-2 text-gray-600">A interface de chat será construída aqui na próxima etapa.</p>
      </div>
    </div>
  );
}
EOF
echo "  -> Link adicionado ao Dashboard."
echo ""

cd ..
echo "--- ✅ SUCESSO! Etapa 3 concluída. ---"
echo "A fundação para conectar o WhatsApp foi reconstruída."
echo "Execute 'npm run dev' na pasta 'src' e teste o fluxo:"
echo "1. Faça login."
echo "2. Clique em 'Conectar WhatsApp'."
echo "3. Clique em 'Gerar QR Code' e veja se ele aparece."
echo "Quando estiver pronto, passaremos para a Etapa 4 para construir a interface de chat final."