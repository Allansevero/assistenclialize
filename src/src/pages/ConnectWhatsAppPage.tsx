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
