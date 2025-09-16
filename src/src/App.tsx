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
