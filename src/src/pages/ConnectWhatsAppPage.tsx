// /src/pages/ConnectWhatsAppPage.tsx

import { useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';
import { useAuthStore } from '../stores/auth.store';
import { api } from '../lib/api';
import QRCode from 'react-qr-code';
import toast from 'react-hot-toast';
import { Link } from 'react-router-dom';

let socket: Socket;

export function ConnectWhatsAppPage() {
  const { user, token } = useAuthStore();
  const [qrCode, setQrCode] = useState<string | null>(null);
  const [status, setStatus] = useState('Ocioso');

  useEffect(() => {
    socket = io('http://localhost:3000');
    if (user) { socket.emit('join-room', user.id); }
    socket.on('qr-code', (qr: string) => { setQrCode(qr); setStatus('Aguardando escaneamento...'); });
    // Pull de QR como fallback
    const interval = setInterval(async () => {
      if (!user || status === 'Conectado!' || status.startsWith('Conectado')) return;
      try {
        const { data } = await api.get('/whatsapp/sessions/latest-qr', { headers: { Authorization: `Bearer ${token}` } });
        if (data?.qr) {
          setQrCode(data.qr);
          if (!status.toLowerCase().includes('aguardando')) setStatus('Aguardando escaneamento...');
        }
      } catch {}
    }, 2000);
    
    socket.on('session-ready', (data) => {
      toast.success(data.message);
      setStatus('Conectado! Salvando no banco de dados...');
      
      api.post(`/whatsapp/sessions/persist`, {}, {
        headers: { Authorization: `Bearer ${token}` }
      }).then(() => {
        toast.success('Sessão salva com sucesso no banco de dados!');
        setStatus('Conectado e Salvo no DB!');
      }).catch(() => {
        toast.error('Falha ao salvar a sessão no banco.');
        setStatus('Conectado, mas falha ao salvar no DB.');
      });
      
      setQrCode(null);
    });

    return () => { clearInterval(interval); socket.disconnect(); };
  }, [user, token]);

  async function handleStartConnection(force: boolean = true) {
    setStatus('Iniciando conexão...');
    setQrCode(null);
    try {
      await api.post(`/whatsapp/sessions/connect?force=${force ? 'true' : 'false'}`, {}, { headers: { Authorization: `Bearer ${token}` } });
      setStatus('Aguardando o QR Code...');
    } catch (error) {
      toast.error('Não foi possível iniciar a conexão.');
      setStatus('Erro.');
    }
  }

  return (
    <div className="p-8">
      <Link to="/dashboard">&larr; Voltar</Link>
      <h1 className="text-2xl font-bold mt-4">Conectar Nova Conta de WhatsApp</h1>
      <div className="mt-4 p-4 border rounded-md">
        <p><b>Status:</b> {status}</p>
        <button onClick={() => handleStartConnection(true)} disabled={status !== 'Ocioso' && status !== 'Erro.'}>Iniciar Conexão (forçar novo QR)</button>
        {qrCode && (
          <div className="mt-6">
            <p>Escaneie o QR Code:</p>
            <div style={{ background: 'white', padding: '16px' }}><QRCode value={qrCode} size={256} /></div>
          </div>
        )}
      </div>
    </div>
  );
}