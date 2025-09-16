#!/bin/bash

echo "--- Iniciando a Construção da Interface de Conexão WhatsApp ---"
echo ""

# Navega para a pasta do frontend
cd src

# --- Passo 1: Instalar Novas Dependências ---
echo "[1/4] Instalando socket.io-client e qrcode.react..."
npm install socket.io-client qrcode.react
echo "Dependências instaladas com sucesso."
echo ""

# --- Passo 2: Criar a Nova Página de Conexão ---
echo "[2/4] Criando a página src/pages/ConnectWhatsAppPage.tsx..."
cat << 'EOF' > src/pages/ConnectWhatsAppPage.tsx
import { useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import { useAuthStore } from '../stores/auth.store';
import { api } from '../lib/api';
import QRCode from 'qrcode.react';
import toast from 'react-hot-toast';
import { Link } from 'react-router-dom';

let socket: Socket;

export function ConnectWhatsAppPage() {
  const { user, token } = useAuthStore();
  const [qrCode, setQrCode] = useState<string | null>(null);
  const [status, setStatus] = useState('Ocioso');

  useEffect(() => {
    // Conecta ao servidor de socket quando o componente é montado
    socket = io('http://localhost:3000');

    // Junta-se a uma sala privada para receber eventos
    if (user) {
      socket.emit('join-room', user.id);
    }

    socket.on('connect', () => {
      console.log('Conectado ao servidor de socket!');
    });
    
    socket.on('qr-code', (qr: string) => {
      console.log('QR Code recebido!');
      setQrCode(qr);
      setStatus('Aguardando escaneamento do QR Code...');
    });
    
    socket.on('session-ready', (data) => {
      toast.success(data.message);
      setStatus('Conectado!');
      setQrCode(null);
    });
    
    socket.on('auth-failure', (data) => {
      toast.error(data.message);
      setStatus('Falha na autenticação.');
    });

    // Limpeza: desconecta do socket quando o componente é desmontado
    return () => {
      socket.disconnect();
    };
  }, [user]);

  async function handleStartConnection() {
    if (!token) {
      toast.error('Você precisa estar logado.');
      return;
    }
    setStatus('Iniciando conexão...');
    setQrCode(null);
    try {
      await api.post('/whatsapp/sessions/connect', {}, {
        headers: {
          Authorization: `Bearer ${token}`
        }
      });
      setStatus('Aguardando o QR Code do servidor...');
    } catch (error) {
      toast.error('Não foi possível iniciar a conexão.');
      setStatus('Erro.');
    }
  }

  return (
    <div className="p-8">
      <Link to="/dashboard" className="text-blue-500 mb-4 inline-block">&larr; Voltar para o Dashboard</Link>
      <h1 className="text-2xl font-bold">Conectar Nova Conta de WhatsApp</h1>
      <div className="mt-4 p-4 border rounded-md">
        <p className="mb-4"><b>Status:</b> {status}</p>
        
        {status !== 'Conectado!' && (
          <button 
            onClick={handleStartConnection} 
            className="px-4 py-2 text-white bg-blue-600 rounded hover:bg-blue-700"
            disabled={status !== 'Ocioso' && status !== 'Erro.'}
          >
            Iniciar Conexão
          </button>
        )}

        {qrCode && (
          <div className="mt-6 flex flex-col items-center">
            <p className="mb-2">Escaneie o QR Code com o seu celular:</p>
            <div className="p-4 bg-white inline-block">
               <QRCode value={qrCode} size={256} />
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
EOF
echo "  -> src/pages/ConnectWhatsAppPage.tsx (Criado)"
echo ""

# --- Passo 3: Atualizar o Dashboard ---
echo "[3/4] Adicionando link para a nova página no Dashboard..."
cat << 'EOF' > src/pages/Dashboard.tsx
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
        <h1 className="text-2xl font-bold">Bem-vindo ao Dashboard, {user?.name}!</h1>
        <button onClick={handleLogout} className="px-4 py-2 text-white bg-red-600 rounded hover:bg-red-700">Sair (Logout)</button>
      </div>
      
      <div className="mt-8">
        <h2 className="text-xl font-semibold">Sessões de WhatsApp</h2>
        <div className="mt-4 p-4 border rounded-md">
          {/* Aqui listaremos as sessões no futuro */}
          <p>Nenhuma sessão conectada ainda.</p>
          <Link to="/connect-whatsapp">
            <button className="mt-4 px-4 py-2 text-white bg-green-600 rounded hover:bg-green-700">
              + Conectar Nova Conta
            </button>
          </Link>
        </div>
      </div>
    </div>
  )
}
EOF
echo "  -> src/pages/Dashboard.tsx (Atualizado)"
echo ""

# --- Passo 4: Atualizar as Rotas ---
echo "[4/4] Adicionando a nova rota protegida em App.tsx..."
cat << 'EOF' > src/App.tsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { LoginPage } from './pages/Login';
import { RegisterPage } from './pages/Register';
import { DashboardPage } from './pages/Dashboard';
import { ConnectWhatsAppPage } from './pages/ConnectWhatsAppPage'; // Importa a nova página
import { Toaster } from 'react-hot-toast';
import { useAuthStore } from './stores/auth.store';

// Componente para proteger rotas
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
        <Route path="/" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
        <Route path="/dashboard" element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
        {/* Nova rota protegida para a conexão */}
        <Route path="/connect-whatsapp" element={<ProtectedRoute><ConnectWhatsAppPage /></ProtectedRoute>} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
EOF
echo "  -> src/App.tsx (Atualizado)"
echo ""

echo "--- SUCESSO! A interface de conexão foi criada. ---"