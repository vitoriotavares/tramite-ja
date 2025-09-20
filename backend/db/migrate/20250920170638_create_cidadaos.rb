class CreateCidadaos < ActiveRecord::Migration[8.0]
  def change
    create_table :cidadaos, id: :uuid do |t|
      t.string :cpf, null: false, limit: 11
      t.string :nome_completo, null: false, limit: 255
      t.string :email, null: false, limit: 255
      t.string :telefone, limit: 15
      t.text :endereco_completo
      t.string :oauth_gov_id, null: false, limit: 255
      t.datetime :data_cadastro, null: false

      t.timestamps
    end

    # Índices para performance
    add_index :cidadaos, :cpf, unique: true
    add_index :cidadaos, :email
    add_index :cidadaos, :oauth_gov_id, unique: true
    add_index :cidadaos, :data_cadastro
  end
end
