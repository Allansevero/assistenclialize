#!/bin/bash

echo "--- EXECUTANDO A TROCA DA BIBLIOTECA DE QR CODE ---"
echo "Removendo 'qrcode.react' e instalando 'react-qr-code' como alternativa."
echo ""
sleep 2

# Navega para a pasta do frontend
cd src

# --- Passo 1: Desinstalar a biblioteca problemática ---
echo "[1/3] Desinstalando a biblioteca 'qrcode.react'..."
npm uninstall qrcode.react
echo "Biblioteca antiga removida."
echo ""

# --- Passo 2: Instalar a nova biblioteca ---
echo "[2/3] Instalando a nova biblioteca 'react-qr-code'..."
npm install react-qr-code
echo "Nova biblioteca instalada com sucesso."
echo ""

# --- Passo 3: Atualizar o código para usar a nova biblioteca ---
echo "[3/3] Atualizando o arquivo ConnectWhatsAppPage.tsx..."
cat << 'EOF' > src/pages/ConnectWhatsAppPage.tsx
import { useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import { useAuthStore } from '../stores/auth.store';
import { api } from '../lib/api';
import QRCode from 'react-qr-code'; // --- USANDO A NOVA BIBLIOTECA ---
import toast from 'react-hot-toast';
import { Link } from 'react-router-dom';

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
    socket.on('connect', () => console.log('Conectado ao servidor de socket!'));
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
            {/* A nova biblioteca tem uma sintaxe um pouco diferente, mais limpa */}
            <div style={{ background: 'white', padding: '16px' }}>
               <QRCode value={qrCode} size={256} />
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
EOF
echo "  -> src/pages/ConnectWhatsAppPage.tsx (Atualizado para a nova biblioteca)"
echo ""

echo "--- SUCESSO! A biblioteca de QR Code foi substituída. ---"
echo "Por favor, reinicie o servidor de desenvolvimento do frontend."