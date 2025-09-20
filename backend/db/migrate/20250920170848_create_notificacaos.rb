class CreateNotificacaos < ActiveRecord::Migration[8.0]
  def change
    create_table :notificacaos do |t|
      t.references :processo, null: false, foreign_key: true
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
