class Cidadao < ApplicationRecord
  # Relacionamentos
  has_many :processos, dependent: :destroy

  # Validações
  validates :cpf, presence: true, uniqueness: true, length: { is: 11 }
  validates :nome_completo, presence: true, length: { maximum: 255 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :oauth_gov_id, presence: true, uniqueness: true

  # Callbacks
  before_create :set_data_cadastro

  # Métodos
  def cpf_formatado
    return cpf if cpf.blank? || cpf.length != 11
    "#{cpf[0..2]}.#{cpf[3..5]}.#{cpf[6..8]}-#{cpf[9..10]}"
  end

  def telefone_formatado
    return telefone if telefone.blank? || telefone.length < 10
    if telefone.length == 11
      "(#{telefone[0..1]}) #{telefone[2..6]}-#{telefone[7..10]}"
    else
      "(#{telefone[0..1]}) #{telefone[2..5]}-#{telefone[6..9]}"
    end
  end

  private

  def set_data_cadastro
    self.data_cadastro ||= Time.current
  end
end
