class CreateJulgadors < ActiveRecord::Migration[8.0]
  def change
    create_table :julgadors do |t|
      t.string :nome
      t.string :registro_profissional
      t.string :email
      t.text :especializacoes
      t.boolean :disponivel
      t.text :historico_votos
      t.datetime :data_cadastro

      t.timestamps
    end
  end
end
