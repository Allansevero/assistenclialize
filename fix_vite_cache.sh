#!/bin/bash

echo "--- EXECUTANDO RESET DE FÁBRICA DO AMBIENTE FRONTEND ---"
echo "Isso irá limpar o cache do Vite e forçar uma reinstalação limpa."
echo ""
sleep 2

# Navega para a pasta do frontend
cd src

# --- Passo 1: Limpar o Cache do Vite ---
echo "[1/4] Limpando o cache do Vite em node_modules/.vite..."
rm -rf node_modules/.vite
echo "Cache do Vite limpo."
echo ""

# --- Passo 2: Reinstalação Profunda ---
echo "[2/4] Removendo node_modules e package-lock.json..."
rm -rf node_modules
rm -f package-lock.json
echo "Iniciando reinstalação limpa..."
npm install
echo "Dependências reinstaladas com sucesso."
echo ""

# --- Passo 3: Aplicar a Importação Padrão Correta ---
# Com o cache limpo, a importação 'default' que é o padrão da biblioteca, deve funcionar.
echo "[3/4] Corrigindo a importação no arquivo ConnectWhatsAppPage.tsx..."
cat << 'EOF' > src/pages/ConnectWhatsAppPage.tsx
import { useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import { useAuthStore } from '../stores/auth.store';
import { api } from '../lib/api';
import QRCode from 'qrcode.react'; // --- VOLTANDO PARA A IMPORTAÇÃO PADRÃO ---
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

# --- Passo 4: Finalização ---
echo "[4/4] O reset de fábrica foi concluído."
echo ""
echo "--- SUCESSO! O ambiente foi totalmente limpo. ---"
echo "Por favor, reinicie o servidor de desenvolvimento do frontend."