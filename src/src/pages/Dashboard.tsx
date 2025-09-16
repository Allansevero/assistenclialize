import { useEffect, useState } from "react";
import { useAuthStore } from "../stores/auth.store";
import { Link, useNavigate } from "react-router-dom";
import { api } from "../lib/api";

// Define a tipagem de uma sessão para o frontend
interface WhatsappSession {
  id: string;
  name: string | null;
  status: string;
}

export function DashboardPage() {
  const { user, token, logout } = useAuthStore();
  const navigate = useNavigate();
  const [sessions, setSessions] = useState<WhatsappSession[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    async function fetchSessions() {
      if (!token) return;
      try {
        setIsLoading(true);
        const response = await api.get('/whatsapp/sessions', {
          headers: { Authorization: `Bearer ${token}` }
        });
        setSessions(response.data);
      } catch (error) {
        console.error("Erro ao buscar sessões:", error);
      } finally {
        setIsLoading(false);
      }
    }
    fetchSessions();
  }, [token]);

  function handleLogout() {
    logout();
    navigate('/login');
  }
  
  return (
    <div className="p-8 max-w-4xl mx-auto">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold">Bem-vindo, {user?.name}!</h1>
        <button onClick={handleLogout} className="px-4 py-2 text-white bg-red-600 rounded hover:bg-red-700">Sair (Logout)</button>
      </div>
      
      <div>
        <div className="flex justify-between items-center">
            <h2 className="text-2xl font-semibold">Suas Conexões</h2>
            <Link to="/connect-whatsapp">
                <button className="px-4 py-2 text-white bg-green-600 rounded hover:bg-green-700">+ Conectar Nova Conta</button>
            </Link>
        </div>
        
        <div className="mt-4 p-4 border rounded-md bg-white shadow-sm">
          {isLoading ? (
            <p>Carregando sessões...</p>
          ) : sessions.length > 0 ? (
            <ul className="space-y-3">
              {sessions.map(session => (
                <li key={session.id} className="p-3 border rounded-lg flex justify-between items-center">
                  <span>{session.name || session.id}</span>
                  <span className={`px-3 py-1 text-sm rounded-full ${session.status === 'CONNECTED' ? 'bg-green-200 text-green-800' : 'bg-gray-200 text-gray-800'}`}>
                    {session.status}
                  </span>
                </li>
              ))}
            </ul>
          ) : (
            <p>Nenhuma sessão conectada ainda.</p>
          )}
        </div>
      </div>
    </div>
  )
}
