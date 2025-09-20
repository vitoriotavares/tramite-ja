class CreateDocumentos < ActiveRecord::Migration[8.0]
  def change
    create_table :documentos do |t|
      t.references :processo, null: false, foreign_key: true
      t.integer :tipo
      t.string :nome_arquivo
      t.string :url_armazenamento
      t.bigint :tamanho_bytes
      t.string :tipo_mime
      t.integer :status_validacao
      t.text :motivo_rejeicao
      t.datetime :data_upload

      t.timestamps
    end
  end
end
