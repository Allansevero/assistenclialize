import { useEffect, useState } from "react";
import { useAuthStore } from "../stores/auth.store";
import { Link, useNavigate } from "react-router-dom";
import { api } from "../lib/api";

type SimpleSession = { id: string; name: string | null; status: string };

export function DashboardPage() {
  const { user, token, logout } = useAuthStore();
  const navigate = useNavigate();
  const [sessions, setSessions] = useState<SimpleSession[]>([]);
  const [selectedSessionId, setSelectedSessionId] = useState<string | null>(null);

  useEffect(() => {
    async function loadSessions() {
      try {
        const resp = await api.get("/whatsapp/sessions", {
          headers: { Authorization: `Bearer ${token}` },
        });
        setSessions(resp.data.sessions ?? []);
      } catch (e) {
        // noop
      }
    }
    if (token) loadSessions();
  }, [token]);

  function handleLogout() {
    logout();
    navigate('/login');
  }
  
  return (
    <div className="p-0">
      <div className="flex justify-between items-center p-8">
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
      <div className="flex h-[calc(100vh-96px)]">
        <aside className="w-64 border-r bg-white">
          <div className="p-4 border-b">
            <h2 className="font-semibold">Suas Sessões</h2>
          </div>
          <ul className="divide-y">
            {sessions.map((s) => (
              <li key={s.id} className={`p-3 cursor-pointer hover:bg-gray-50 ${selectedSessionId === s.id ? 'bg-gray-100' : ''}`} onClick={() => setSelectedSessionId(s.id)}>
                <div className="flex items-center justify-between">
                  <span className="truncate max-w-[11rem]" title={s.name || s.id}>{s.name || s.id}</span>
                  <span className={`text-xs px-2 py-0.5 rounded ${s.status === 'CONNECTED' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'}`}>{s.status}</span>
                </div>
              </li>
            ))}
            {sessions.length === 0 && (
              <li className="p-3 text-sm text-gray-500">Nenhuma sessão ainda.</li>
            )}
          </ul>
        </aside>
        <main className="flex-1 p-6">
          <div className="p-6 border rounded-lg bg-white shadow-sm h-full">
            <h2 className="text-xl font-semibold">Chat</h2>
            {!selectedSessionId && (
              <p className="mt-2 text-gray-600">Selecione uma sessão na barra lateral para começar.</p>
            )}
            {selectedSessionId && (
              <div className="mt-4 text-gray-700">Sessão selecionada: {selectedSessionId}</div>
            )}
          </div>
        </main>
      </div>
    </div>
  );
}
