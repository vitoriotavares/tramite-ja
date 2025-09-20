'use client';

import { useEffect, useState } from 'react';
import { io, Socket } from 'socket.io-client';

interface UseSocketOptions {
  autoConnect?: boolean;
}

interface SocketState {
  socket: Socket | null;
  connected: boolean;
  error: string | null;
}

/**
 * Hook para gerenciar conexão Socket.io com o backend TrâmiteJá
 * Usado para notificações em tempo real de processos, votação e status updates
 */
export function useSocket(options: UseSocketOptions = {}) {
  const { autoConnect = true } = options;

  const [socketState, setSocketState] = useState<SocketState>({
    socket: null,
    connected: false,
    error: null,
  });

  useEffect(() => {
    if (!autoConnect) return;

    // URL do backend Socket.io server
    const socketUrl = process.env.NEXT_PUBLIC_SOCKET_URL || 'ws://localhost:3001';

    const newSocket = io(socketUrl, {
      // Configurações de reconexão
      autoConnect: true,
      reconnection: true,
      reconnectionAttempts: 5,
      reconnectionDelay: 1000,
      // Transporte preferencial
      transports: ['websocket', 'polling'],
    });

    // Event listeners para estados da conexão
    newSocket.on('connect', () => {
      setSocketState(prev => ({
        ...prev,
        connected: true,
        error: null,
      }));
    });

    newSocket.on('disconnect', () => {
      setSocketState(prev => ({
        ...prev,
        connected: false,
      }));
    });

    newSocket.on('connect_error', (error) => {
      setSocketState(prev => ({
        ...prev,
        connected: false,
        error: error.message,
      }));
    });

    setSocketState(prev => ({
      ...prev,
      socket: newSocket,
    }));

    return () => {
      newSocket.close();
    };
  }, [autoConnect]);

  // Funções de utilidade
  const emit = (event: string, data?: any) => {
    if (socketState.socket && socketState.connected) {
      socketState.socket.emit(event, data);
    }
  };

  const on = (event: string, callback: (...args: any[]) => void) => {
    if (socketState.socket) {
      socketState.socket.on(event, callback);

      // Retorna função para cleanup
      return () => {
        socketState.socket?.off(event, callback);
      };
    }
  };

  const off = (event: string, callback?: (...args: any[]) => void) => {
    if (socketState.socket) {
      socketState.socket.off(event, callback);
    }
  };

  return {
    socket: socketState.socket,
    connected: socketState.connected,
    error: socketState.error,
    emit,
    on,
    off,
  };
}