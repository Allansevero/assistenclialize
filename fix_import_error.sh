#!/bin/bash

echo "--- Corrigindo o Erro de Importação na Página de Conexão WhatsApp ---"
echo ""

# Navega para a pasta do frontend
cd src

# --- Passo 1: Sobrescrever o arquivo com a importação corrigida ---
echo "[1/1] Atualizando o arquivo src/pages/ConnectWhatsAppPage.tsx..."
cat << 'EOF' > src/pages/ConnectWhatsAppPage.tsx
import { useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import { useAuthStore } from '../stores/auth.store';
import { api } from '../lib/api';
import { QRCode } from 'qrcode.react'; // --- ESTA É A LINHA CORRIGIDA ---
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
echo "  -> src/pages/ConnectWhatsAppPage.tsx (Corrigido)"
echo ""

echo "--- SUCESSO! O erro de importação foi corrigido. ---"
echo "O servidor de desenvolvimento irá recarregar automaticamente."