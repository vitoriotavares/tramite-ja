class CreateVotos < ActiveRecord::Migration[8.0]
  def change
    create_table :votos, id: :uuid do |t|
      t.references :processo, null: false, foreign_key: true, type: :uuid
      t.references :julgador, null: false, foreign_key: true, type: :uuid
      t.integer :decisao
      t.text :justificativa
      t.datetime :data_voto
      t.integer :tempo_analise

      t.timestamps
    end
  end
end
