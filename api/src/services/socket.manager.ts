import { Server as SocketIOServer } from 'socket.io';
import http from 'http';

class SocketManager {
    private static instance: SocketManager;
    public io: SocketIOServer | null = null;

    private constructor() { }

    public static getInstance(): SocketManager {
        if (!this.instance) {
            this.instance = new SocketManager();
        }
        return this.instance;
    }

    public initialize(server: http.Server) {
        this.io = new SocketIOServer(server, { cors: { origin: '*' } });
        this.io.on('connection', (socket) => {
            console.log(`[Socket.IO] Novo cliente conectado: ${socket.id}`);
            socket.on('join-room', (userId) => {
                socket.join(userId);
            });
        });
    }

    public emitToUser(userId: string, event: string, data: any) {
        this.io?.to(userId).emit(event, data);
    }
}

export const socketManager = SocketManager.getInstance();
