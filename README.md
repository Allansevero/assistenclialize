# Assistenclialize

Um Micro SaaS que permite gerenciar múltiplas contas de WhatsApp simultaneamente em uma única interface web.

## 🎯 Problema

Profissionais que precisam gerenciar várias contas de WhatsApp enfrentam o problema de ter que trocar constantemente entre abas/navegadores, causando context switches desnecessários e reduzindo a produtividade.

## 💡 Solução

O Assistenclialize oferece:
- **Múltiplas sessões de WhatsApp lado a lado** em uma única interface
- **Sessões persistidas na nuvem** - acesse de qualquer dispositivo
- **Interface unificada** com sidebar mostrando avatares das sessões
- **Chat em tempo real** para cada sessão conectada
- **Gerenciamento de equipes** para organizações

## 🏗️ Arquitetura

### Backend (API)
- **Node.js** com TypeScript
- **PostgreSQL** como banco de dados
- **Prisma ORM** para gerenciamento de dados
- **Socket.IO** para comunicação em tempo real
- **WhatsApp Web.js** para integração com WhatsApp
- **JWT** para autenticação
- **Docker** para containerização

### Frontend
- **React** com TypeScript
- **Vite** como bundler
- **React Router** para navegação
- **Socket.IO client** para tempo real
- **React Hot Toast** para notificações

## 🚀 Como executar

### Pré-requisitos
- Node.js 18+
- Docker e Docker Compose
- PostgreSQL (ou use o Docker Compose)

### Instalação

1. **Clone o repositório**
```bash
git clone <seu-repositorio>
cd assistenclialize
```

2. **Configure o banco de dados**
```bash
docker-compose up -d db
```

3. **Configure as variáveis de ambiente**
```bash
# Na pasta api/
cp .env.example .env
# Edite o arquivo .env com suas configurações
```

4. **Instale as dependências**
```bash
# Backend
cd api
npm install
npx prisma migrate dev
npx prisma generate

# Frontend
cd ../src
npm install
```

5. **Execute o projeto**
```bash
# Backend (terminal 1)
cd api
npm run dev

# Frontend (terminal 2)
cd src
npm run dev
```

## 📊 KPIs do MVP

- Reduzir context switches por operador/hora
- Aumentar conversas/hora
- Reduzir time-to-first-response
- Guardrails: ban rate, error rate de envio/recebimento, consumo CPU/RAM cliente

## 🛠️ Funcionalidades

- [x] Autenticação de usuários (login/registro)
- [x] Conexão de contas WhatsApp via QR Code
- [x] Persistência de sessões no banco de dados
- [x] Listagem de sessões no dashboard
- [x] Chat em tempo real para cada sessão
- [x] Gerenciamento de equipes
- [ ] Interface de chat completa
- [ ] Envio de mensagens
- [ ] Histórico de conversas
- [ ] Notificações em tempo real

## 📁 Estrutura do Projeto

```
assistenclialize/
├── api/                    # Backend (Node.js + TypeScript)
│   ├── src/
│   │   ├── features/       # Features organizadas por domínio
│   │   │   ├── auth/       # Autenticação
│   │   │   ├── teams/      # Gerenciamento de equipes
│   │   │   └── whatsapp/   # Integração WhatsApp
│   │   ├── middleware/     # Middlewares
│   │   └── server.ts       # Servidor principal
│   ├── prisma/             # Schema e migrações do banco
│   └── package.json
├── src/                    # Frontend (React + TypeScript)
│   ├── src/
│   │   ├── pages/          # Páginas da aplicação
│   │   ├── stores/         # Estado global (Zustand)
│   │   ├── lib/            # Utilitários e API client
│   │   └── App.tsx         # Componente principal
│   └── package.json
├── docker-compose.yml      # Configuração do banco
└── README.md
```

## 🔧 Scripts de Desenvolvimento

O projeto inclui vários scripts shell para facilitar o desenvolvimento:
- `create_whatsapp_service.sh` - Configura o serviço WhatsApp
- `create_whatsapp_ui.sh` - Cria a interface de conexão
- `show_sessions_on_dashboard.sh` - Integra sessões no dashboard
- E muitos outros...

## 📝 Licença

ISC

## 🤝 Contribuição

Este é um projeto em desenvolvimento ativo. Contribuições são bem-vindas!

## 📞 Contato

Para dúvidas ou sugestões, abra uma issue no repositório.
