# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_20_171005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "cidadaos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cpf", limit: 11, null: false
    t.string "nome_completo", limit: 255, null: false
    t.string "email", limit: 255, null: false
    t.string "telefone", limit: 15
    t.text "endereco_completo"
    t.string "oauth_gov_id", limit: 255, null: false
    t.datetime "data_cadastro", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cpf"], name: "index_cidadaos_on_cpf", unique: true
    t.index ["data_cadastro"], name: "index_cidadaos_on_data_cadastro"
    t.index ["email"], name: "index_cidadaos_on_email"
    t.index ["oauth_gov_id"], name: "index_cidadaos_on_oauth_gov_id", unique: true
  end

  create_table "documentos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "processo_id", null: false
    t.integer "tipo"
    t.string "nome_arquivo"
    t.string "url_armazenamento"
    t.bigint "tamanho_bytes"
    t.string "tipo_mime"
    t.integer "status_validacao"
    t.text "motivo_rejeicao"
    t.datetime "data_upload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["processo_id", "tipo"], name: "index_documentos_on_processo_id_and_tipo"
    t.index ["processo_id"], name: "index_documentos_on_processo_id"
    t.index ["status_validacao"], name: "index_documentos_on_status_validacao"
    t.check_constraint "tamanho_bytes > 0", name: "tamanho_bytes_positive"
  end

  create_table "julgadors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "nome"
    t.string "registro_profissional"
    t.string "email"
    t.text "especializacoes"
    t.boolean "disponivel"
    t.text "historico_votos"
    t.datetime "data_cadastro"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["disponivel"], name: "index_julgadors_on_disponivel"
    t.index ["email"], name: "index_julgadors_on_email", unique: true
    t.index ["registro_profissional"], name: "index_julgadors_on_registro_profissional", unique: true
  end

  create_table "notificacaos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "processo_id", null: false
    t.string "destinatario_email"
    t.integer "tipo"
    t.string "assunto"
    t.text "conteudo"
    t.integer "status_envio"
    t.datetime "data_criacao"
    t.datetime "data_envio"
    t.integer "tentativas"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_criacao"], name: "index_notificacaos_on_data_criacao"
    t.index ["processo_id", "tipo"], name: "index_notificacaos_on_processo_id_and_tipo"
    t.index ["processo_id"], name: "index_notificacaos_on_processo_id"
    t.index ["status_envio"], name: "index_notificacaos_on_status_envio"
    t.check_constraint "tentativas <= 3", name: "tentativas_max_three"
    t.check_constraint "tentativas >= 0", name: "tentativas_non_negative"
  end

  create_table "processos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "codigo_acompanhamento"
    t.integer "tipo_infracao"
    t.integer "status"
    t.uuid "cidadao_id", null: false
    t.uuid "relator_id"
    t.datetime "data_criacao"
    t.datetime "data_limite"
    t.datetime "data_decisao"
    t.text "parecer_relator"
    t.integer "decisao_final"
    t.text "justificativa_rejeicao"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cidadao_id"], name: "index_processos_on_cidadao_id"
    t.index ["codigo_acompanhamento"], name: "index_processos_on_codigo_acompanhamento", unique: true
    t.index ["data_criacao"], name: "index_processos_on_data_criacao"
    t.index ["relator_id"], name: "index_processos_on_relator_id"
    t.index ["status", "data_limite"], name: "index_processos_on_status_and_data_limite"
    t.check_constraint "data_limite > data_criacao", name: "data_limite_after_criacao"
  end

  create_table "relators", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "nome"
    t.string "registro_oab"
    t.string "email"
    t.text "especializacoes"
    t.integer "capacidade_maxima"
    t.integer "processos_ativos"
    t.boolean "disponivel"
    t.text "metricas_performance"
    t.datetime "data_cadastro"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["disponivel", "processos_ativos"], name: "index_relators_on_disponivel_and_processos_ativos"
    t.index ["email"], name: "index_relators_on_email", unique: true
    t.index ["registro_oab"], name: "index_relators_on_registro_oab", unique: true
    t.check_constraint "capacidade_maxima > 0", name: "capacidade_maxima_positive"
    t.check_constraint "processos_ativos <= capacidade_maxima", name: "processos_within_capacity"
    t.check_constraint "processos_ativos >= 0", name: "processos_ativos_non_negative"
  end

  create_table "votos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "processo_id", null: false
    t.uuid "julgador_id", null: false
    t.integer "decisao"
    t.text "justificativa"
    t.datetime "data_voto"
    t.integer "tempo_analise"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_voto"], name: "index_votos_on_data_voto"
    t.index ["julgador_id"], name: "index_votos_on_julgador_id"
    t.index ["processo_id", "julgador_id"], name: "index_votos_on_processo_id_and_julgador_id", unique: true
    t.index ["processo_id"], name: "index_votos_on_processo_id"
    t.check_constraint "tempo_analise >= 0", name: "tempo_analise_non_negative"
  end

  add_foreign_key "documentos", "processos"
  add_foreign_key "notificacaos", "processos"
  add_foreign_key "processos", "cidadaos"
  add_foreign_key "processos", "relators"
  add_foreign_key "votos", "julgadors"
  add_foreign_key "votos", "processos"
end
