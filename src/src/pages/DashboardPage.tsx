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
