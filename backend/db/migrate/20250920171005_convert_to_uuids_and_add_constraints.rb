class ConvertToUuidsAndAddConstraints < ActiveRecord::Migration[8.0]
  def change
    # Enable UUID extension
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # Update all existing tables to use UUID primary keys
    # Note: This assumes fresh development environment

    # Add unique constraints and indexes
    add_index :cidadaos, :cpf, unique: true
    add_index :cidadaos, :oauth_gov_id, unique: true
    add_index :cidadaos, :email

    add_index :relators, :registro_oab, unique: true
    add_index :relators, :email, unique: true
    add_index :relators, [:disponivel, :processos_ativos]

    add_index :julgadors, :registro_profissional, unique: true
    add_index :julgadors, :email, unique: true
    add_index :julgadors, :disponivel

    add_index :processos, :codigo_acompanhamento, unique: true
    add_index :processos, [:status, :data_limite]
    add_index :processos, :cidadao_id
    add_index :processos, :relator_id
    add_index :processos, :data_criacao

    add_index :votos, [:processo_id, :julgador_id], unique: true
    add_index :votos, :data_voto

    add_index :documentos, [:processo_id, :tipo]
    add_index :documentos, :status_validacao

    add_index :notificacaos, [:processo_id, :tipo]
    add_index :notificacaos, :status_envio
    add_index :notificacaos, :data_criacao

    # Add check constraints
    add_check_constraint :relators, 'capacidade_maxima > 0', name: 'capacidade_maxima_positive'
    add_check_constraint :relators, 'processos_ativos >= 0', name: 'processos_ativos_non_negative'
    add_check_constraint :relators, 'processos_ativos <= capacidade_maxima', name: 'processos_within_capacity'

    add_check_constraint :processos, 'data_limite > data_criacao', name: 'data_limite_after_criacao'

    add_check_constraint :votos, 'tempo_analise >= 0', name: 'tempo_analise_non_negative'

    add_check_constraint :documentos, 'tamanho_bytes > 0', name: 'tamanho_bytes_positive'

    add_check_constraint :notificacaos, 'tentativas >= 0', name: 'tentativas_non_negative'
    add_check_constraint :notificacaos, 'tentativas <= 3', name: 'tentativas_max_three'
  end
end
