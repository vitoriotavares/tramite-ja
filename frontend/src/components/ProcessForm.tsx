'use client'

import { useState } from 'react'
import { Button } from './ui/button'
import { Input } from './ui/input'
import { Label } from './ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select'
import { cn } from '@/lib/utils'

interface ProcessFormData {
  tipo_infracao: string
  cidadao_cpf: string
  cidadao_nome: string
  cidadao_email: string
  cidadao_telefone: string
}

interface ProcessFormProps {
  onSubmit: (data: ProcessFormData) => Promise<void>
  loading?: boolean
  className?: string
}

const TIPOS_INFRACAO = [
  { value: 'velocidade', label: 'Excesso de Velocidade' },
  { value: 'rodizio', label: 'Rodízio Municipal' },
  { value: 'semaforo', label: 'Desrespeito ao Semáforo' }
]

export function ProcessForm({ onSubmit, loading = false, className }: ProcessFormProps) {
  const [formData, setFormData] = useState<ProcessFormData>({
    tipo_infracao: '',
    cidadao_cpf: '',
    cidadao_nome: '',
    cidadao_email: '',
    cidadao_telefone: ''
  })

  const [errors, setErrors] = useState<Partial<ProcessFormData>>({})

  const formatCPF = (value: string) => {
    // Remove tudo que não é dígito
    const numbers = value.replace(/\D/g, '')

    // Limita a 11 dígitos
    const limited = numbers.slice(0, 11)

    // Aplica máscara XXX.XXX.XXX-XX
    return limited.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, '$1.$2.$3-$4')
  }

  const formatPhone = (value: string) => {
    // Remove tudo que não é dígito
    const numbers = value.replace(/\D/g, '')

    // Limita a 11 dígitos
    const limited = numbers.slice(0, 11)

    // Aplica máscara (XX) XXXXX-XXXX ou (XX) XXXX-XXXX
    if (limited.length === 11) {
      return limited.replace(/(\d{2})(\d{5})(\d{4})/, '($1) $2-$3')
    } else if (limited.length === 10) {
      return limited.replace(/(\d{2})(\d{4})(\d{4})/, '($1) $2-$3')
    }

    return limited
  }

  const validateCPF = (cpf: string): boolean => {
    // Remove formatação
    const numbers = cpf.replace(/\D/g, '')

    if (numbers.length !== 11) return false

    // Verifica se todos os dígitos são iguais
    if (/^(\d)\1{10}$/.test(numbers)) return false

    // Validação do primeiro dígito verificador
    let sum = 0
    for (let i = 0; i < 9; i++) {
      sum += parseInt(numbers[i]) * (10 - i)
    }
    let digit1 = 11 - (sum % 11)
    if (digit1 > 9) digit1 = 0

    if (parseInt(numbers[9]) !== digit1) return false

    // Validação do segundo dígito verificador
    sum = 0
    for (let i = 0; i < 10; i++) {
      sum += parseInt(numbers[i]) * (11 - i)
    }
    let digit2 = 11 - (sum % 11)
    if (digit2 > 9) digit2 = 0

    return parseInt(numbers[10]) === digit2
  }

  const validateForm = (): boolean => {
    const newErrors: Partial<ProcessFormData> = {}

    // Validação tipo de infração
    if (!formData.tipo_infracao) {
      newErrors.tipo_infracao = 'Selecione o tipo de infração'
    }

    // Validação CPF
    if (!formData.cidadao_cpf) {
      newErrors.cidadao_cpf = 'CPF é obrigatório'
    } else if (!validateCPF(formData.cidadao_cpf)) {
      newErrors.cidadao_cpf = 'CPF inválido'
    }

    // Validação nome
    if (!formData.cidadao_nome.trim()) {
      newErrors.cidadao_nome = 'Nome completo é obrigatório'
    } else if (formData.cidadao_nome.trim().length < 3) {
      newErrors.cidadao_nome = 'Nome deve ter pelo menos 3 caracteres'
    }

    // Validação email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!formData.cidadao_email) {
      newErrors.cidadao_email = 'Email é obrigatório'
    } else if (!emailRegex.test(formData.cidadao_email)) {
      newErrors.cidadao_email = 'Email inválido'
    }

    // Validação telefone
    const phoneNumbers = formData.cidadao_telefone.replace(/\D/g, '')
    if (!formData.cidadao_telefone) {
      newErrors.cidadao_telefone = 'Telefone é obrigatório'
    } else if (phoneNumbers.length < 10 || phoneNumbers.length > 11) {
      newErrors.cidadao_telefone = 'Telefone deve ter 10 ou 11 dígitos'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleInputChange = (field: keyof ProcessFormData, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }))

    // Limpar erro do campo quando o usuário começar a digitar
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: undefined }))
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!validateForm()) {
      return
    }

    try {
      await onSubmit(formData)
    } catch (error) {
      console.error('Erro ao submeter processo:', error)
    }
  }

  return (
    <div className={cn('w-full max-w-2xl mx-auto', className)}>
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-gray-900 mb-2">
            Nova Defesa de Trânsito
          </h1>
          <p className="text-gray-600">
            Preencha os dados abaixo para iniciar seu processo de defesa digital.
            É gratuito e você receberá um código para acompanhamento.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Tipo de Infração */}
          <div className="space-y-2">
            <Label htmlFor="tipo_infracao" className="text-sm font-medium text-gray-700">
              Tipo de Infração *
            </Label>
            <Select
              value={formData.tipo_infracao}
              onValueChange={(value) => handleInputChange('tipo_infracao', value)}
            >
              <SelectTrigger className={cn(
                "w-full",
                errors.tipo_infracao && "border-red-500 focus:border-red-500"
              )}>
                <SelectValue placeholder="Selecione o tipo de infração" />
              </SelectTrigger>
              <SelectContent>
                {TIPOS_INFRACAO.map((tipo) => (
                  <SelectItem key={tipo.value} value={tipo.value}>
                    {tipo.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {errors.tipo_infracao && (
              <p className="text-sm text-red-600">{errors.tipo_infracao}</p>
            )}
          </div>

          {/* Dados do Cidadão */}
          <div className="border-t pt-6">
            <h2 className="text-lg font-semibold text-gray-900 mb-4">
              Dados Pessoais
            </h2>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* CPF */}
              <div className="space-y-2">
                <Label htmlFor="cidadao_cpf" className="text-sm font-medium text-gray-700">
                  CPF *
                </Label>
                <Input
                  id="cidadao_cpf"
                  type="text"
                  placeholder="000.000.000-00"
                  value={formData.cidadao_cpf}
                  onChange={(e) => handleInputChange('cidadao_cpf', formatCPF(e.target.value))}
                  className={cn(
                    errors.cidadao_cpf && "border-red-500 focus:border-red-500"
                  )}
                  maxLength={14}
                />
                {errors.cidadao_cpf && (
                  <p className="text-sm text-red-600">{errors.cidadao_cpf}</p>
                )}
              </div>

              {/* Nome Completo */}
              <div className="space-y-2">
                <Label htmlFor="cidadao_nome" className="text-sm font-medium text-gray-700">
                  Nome Completo *
                </Label>
                <Input
                  id="cidadao_nome"
                  type="text"
                  placeholder="Seu nome completo"
                  value={formData.cidadao_nome}
                  onChange={(e) => handleInputChange('cidadao_nome', e.target.value)}
                  className={cn(
                    errors.cidadao_nome && "border-red-500 focus:border-red-500"
                  )}
                />
                {errors.cidadao_nome && (
                  <p className="text-sm text-red-600">{errors.cidadao_nome}</p>
                )}
              </div>

              {/* Email */}
              <div className="space-y-2">
                <Label htmlFor="cidadao_email" className="text-sm font-medium text-gray-700">
                  Email *
                </Label>
                <Input
                  id="cidadao_email"
                  type="email"
                  placeholder="seu@email.com"
                  value={formData.cidadao_email}
                  onChange={(e) => handleInputChange('cidadao_email', e.target.value)}
                  className={cn(
                    errors.cidadao_email && "border-red-500 focus:border-red-500"
                  )}
                />
                {errors.cidadao_email && (
                  <p className="text-sm text-red-600">{errors.cidadao_email}</p>
                )}
              </div>

              {/* Telefone */}
              <div className="space-y-2">
                <Label htmlFor="cidadao_telefone" className="text-sm font-medium text-gray-700">
                  Telefone *
                </Label>
                <Input
                  id="cidadao_telefone"
                  type="tel"
                  placeholder="(11) 99999-9999"
                  value={formData.cidadao_telefone}
                  onChange={(e) => handleInputChange('cidadao_telefone', formatPhone(e.target.value))}
                  className={cn(
                    errors.cidadao_telefone && "border-red-500 focus:border-red-500"
                  )}
                  maxLength={15}
                />
                {errors.cidadao_telefone && (
                  <p className="text-sm text-red-600">{errors.cidadao_telefone}</p>
                )}
              </div>
            </div>
          </div>

          {/* Informações Importantes */}
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <h3 className="text-sm font-semibold text-blue-900 mb-2">
              📋 Próximos Passos
            </h3>
            <ul className="text-sm text-blue-800 space-y-1">
              <li>• Após enviar, você receberá um código de acompanhamento</li>
              <li>• Será necessário fazer upload dos documentos obrigatórios</li>
              <li>• O processo é 100% gratuito e digital</li>
              <li>• Prazo máximo: 5 dias úteis para conclusão</li>
            </ul>
          </div>

          {/* Botão Submit */}
          <div className="flex justify-end pt-4">
            <Button
              type="submit"
              disabled={loading}
              className="px-8 py-2 bg-blue-600 hover:bg-blue-700 text-white font-medium"
            >
              {loading ? 'Enviando...' : 'Iniciar Processo'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}