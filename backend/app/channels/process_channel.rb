# Canal Action Cable para atualizações em tempo real de processos
# Usado para notificar cidadãos, relatores e julgadores sobre mudanças de status
class ProcessChannel < ApplicationCable::Channel
  def subscribed
    # Stream para processo específico baseado no ID ou código de acompanhamento
    if params[:processo_id].present?
      stream_from "process_#{params[:processo_id]}"
    elsif params[:codigo_acompanhamento].present?
      stream_from "public_process_#{params[:codigo_acompanhamento]}"
    else
      reject
    end
  end

  def unsubscribed
    # Cleanup quando desconectar
    stop_all_streams
  end

  # Método para julgadores se conectarem a notificações de votação
  def subscribe_to_voting
    if current_user&.julgador?
      stream_from "voting_notifications_#{current_user.id}"
    else
      reject
    end
  end

  # Método para relatores se conectarem a novos processos
  def subscribe_to_assignments
    if current_user&.relator?
      stream_from "relator_assignments_#{current_user.id}"
    else
      reject
    end
  end

  private

  def current_user
    # TODO: Implementar autenticação WebSocket via JWT token
    # Por enquanto retorna nil até implementarmos auth
    nil
  end
end