class CreateProcessos < ActiveRecord::Migration[8.0]
  def change
    create_table :processos, id: :uuid do |t|
      t.string :codigo_acompanhamento
      t.integer :tipo_infracao
      t.integer :status
      t.references :cidadao, null: false, foreign_key: true, type: :uuid
      t.references :relator, null: true, foreign_key: true, type: :uuid
      t.datetime :data_criacao
      t.datetime :data_limite
      t.datetime :data_decisao
      t.text :parecer_relator
      t.integer :decisao_final
      t.text :justificativa_rejeicao

      t.timestamps
    end
  end
end
