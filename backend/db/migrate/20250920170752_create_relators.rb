class CreateRelators < ActiveRecord::Migration[8.0]
  def change
    create_table :relators do |t|
      t.string :nome
      t.string :registro_oab
      t.string :email
      t.text :especializacoes
      t.integer :capacidade_maxima
      t.integer :processos_ativos
      t.boolean :disponivel
      t.text :metricas_performance
      t.datetime :data_cadastro

      t.timestamps
    end
  end
end
