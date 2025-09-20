class CreateNotificacaos < ActiveRecord::Migration[8.0]
  def change
    create_table :notificacaos, id: :uuid do |t|
      t.references :processo, null: false, foreign_key: true, type: :uuid
      t.string :destinatario_email
      t.integer :tipo
      t.string :assunto
      t.text :conteudo
      t.integer :status_envio
      t.datetime :data_criacao
      t.datetime :data_envio
      t.integer :tentativas

      t.timestamps
    end
  end
end
