'use client'

import { useState, useEffect } from 'react'
import { Button } from './ui/button'
import { Label } from './ui/label'
import { Input } from './ui/input'
import { cn } from '@/lib/utils'
import {
  ThumbsUp,
  ThumbsDown,
  FileText,
  User,
  Calendar,
  Clock,
  AlertTriangle,
  CheckCircle,
  Users,
  Scale,
  Eye,
  Download
} from 'lucide-react'

interface ProcessoVotacao {
  id: string
  codigo_acompanhamento: string
  tipo_infracao: string
  status: string
  cidadao_nome: string
  cidadao_cpf: string
  data_criacao: string
  data_limite: string
  parecer_relator: string
  relator_nome: string
  documentos: DocumentoProcesso[]
  votos_existentes: VotoExistente[]
  quorum_necessario: number
  votos_atuais: number
  decisao_quorum?: string
}

interface DocumentoProcesso {
  id: string
  tipo: string
  nome_arquivo: string
  status_validacao: string
  url_visualizacao: string
}

interface VotoExistente {
  id: string
  julgador_nome: string
  decisao: string
  justificativa?: string
  data_voto: string
  especializado: boolean
}

interface VotingInterfaceProps {
  processoId: string
  julgadorId: string
  onVoteSubmitted?: (voto: any) => void
  className?: string
}

export function VotingInterface({
  processoId,
  julgadorId,
  onVoteSubmitted,
  className
}: VotingInterfaceProps) {
  const [processo, setProcesso] = useState<ProcessoVotacao | null>(null)
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [decisao, setDecisao] = useState<'concordo' | 'discordo' | ''>('')
  const [justificativa, setJustificativa] = useState('')
  const [errors, setErrors] = useState<{ [key: string]: string }>({})
  const [jaVotou, setJaVotou] = useState(false)
  const [tempoInicioAnalise] = useState(Date.now())

  useEffect(() => {
    const fetchProcesso = async () => {
      try {
        setLoading(true)

        const response = await fetch(`/api/v1/processos/${processoId}/votos`, {
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('token')}`
          }
        })

        if (!response.ok) {
          throw new Error('Erro ao carregar processo para votação')
        }

        const data = await response.json()
        setProcesso(data.processo)

        // Verificar se o julgador já votou
        const votoExistente = data.processo.votos_existentes.find(
          (voto: VotoExistente) => voto.julgador_id === julgadorId
        )
        setJaVotou(!!votoExistente)

      } catch (error) {
        console.error('Erro ao carregar processo:', error)
      } finally {
        setLoading(false)
      }
    }

    if (processoId) {
      fetchProcesso()
    }
  }, [processoId, julgadorId])

  const validateVote = (): boolean => {
    const newErrors: { [key: string]: string } = {}

    if (!decisao) {
      newErrors.decisao = 'Selecione uma decisão'
    }

    if (decisao === 'discordo' && !justificativa.trim()) {
      newErrors.justificativa = 'Justificativa é obrigatória para votos de discordância'
    }

    if (justificativa.trim() && justificativa.trim().length < 10) {
      newErrors.justificativa = 'Justificativa deve ter pelo menos 10 caracteres'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmitVote = async () => {
    if (!validateVote()) return

    try {
      setSubmitting(true)

      const tempoAnalise = Math.round((Date.now() - tempoInicioAnalise) / 1000) // em segundos

      const votoData = {
        decisao,
        justificativa: justificativa.trim() || null,
        tempo_analise: tempoAnalise
      }

      const response = await fetch(`/api/v1/processos/${processoId}/votos`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        },
        body: JSON.stringify({ voto: votoData })
      })

      if (!response.ok) {
        const errorData = await response.json()
        throw new Error(errorData.message || 'Erro ao submeter voto')
      }

      const resultado = await response.json()

      setJaVotou(true)
      onVoteSubmitted?.(resultado)

      // Recarregar dados do processo para mostrar o voto atualizado
      window.location.reload()

    } catch (error) {
      console.error('Erro ao submeter voto:', error)
      setErrors({ submit: error instanceof Error ? error.message : 'Erro ao submeter voto' })
    } finally {
      setSubmitting(false)
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })
  }

  const getDecisaoColor = (decisao: string) => {
    return decisao === 'concordo' ? 'text-green-600 bg-green-100' : 'text-red-600 bg-red-100'
  }

  const getQuorumProgress = () => {
    if (!processo) return 0
    return (processo.votos_atuais / processo.quorum_necessario) * 100
  }

  const isQuorumCompleto = () => {
    return processo && processo.votos_atuais >= processo.quorum_necessario
  }

  if (loading) {
    return (
      <div className={cn('w-full max-w-6xl mx-auto', className)}>
        <div className="animate-pulse space-y-6">
          <div className="bg-white rounded-lg shadow-md p-6">
            <div className="h-6 bg-gray-200 rounded w-1/3 mb-4"></div>
            <div className="space-y-3">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-4 bg-gray-200 rounded"></div>
              ))}
            </div>
          </div>
        </div>
      </div>
    )
  }

  if (!processo) {
    return (
      <div className={cn('w-full max-w-6xl mx-auto', className)}>
        <div className="text-center py-12">
          <AlertTriangle className="mx-auto h-12 w-12 text-red-500 mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">
            Processo Não Encontrado
          </h3>
          <p className="text-gray-600">O processo solicitado não foi encontrado ou não está disponível para votação.</p>
        </div>
      </div>
    )
  }

  return (
    <div className={cn('w-full max-w-6xl mx-auto space-y-6', className)}>
      {/* Header do Processo */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h1 className="text-2xl font-bold text-gray-900 mb-2">
              Votação do Processo
            </h1>
            <p className="text-gray-600">
              Código: <span className="font-mono font-semibold">{processo.codigo_acompanhamento}</span>
            </p>
          </div>
          <div className="text-right">
            <div className="flex items-center space-x-4">
              <div className="text-sm">
                <Label className="text-gray-500">Quórum</Label>
                <div className="flex items-center space-x-2">
                  <Users className="h-4 w-4 text-gray-400" />
                  <span className="font-semibold">
                    {processo.votos_atuais}/{processo.quorum_necessario}
                  </span>
                </div>
              </div>
              {isQuorumCompleto() && (
                <span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
                  <CheckCircle className="h-4 w-4 mr-1" />
                  Quórum Completo
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Progresso do Quórum */}
        <div className="mb-4">
          <div className="flex justify-between text-sm mb-1">
            <span>Progresso do Quórum</span>
            <span>{Math.round(getQuorumProgress())}%</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div
              className={cn(
                'h-2 rounded-full transition-all duration-300',
                isQuorumCompleto() ? 'bg-green-500' : 'bg-blue-500'
              )}
              style={{ width: `${Math.min(getQuorumProgress(), 100)}%` }}
            />
          </div>
        </div>

        {/* Informações do Processo */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div>
            <Label className="text-sm font-medium text-gray-500">Tipo de Infração</Label>
            <p className="text-lg font-semibold text-gray-900 capitalize">
              {processo.tipo_infracao.replace('_', ' ')}
            </p>
          </div>
          <div>
            <Label className="text-sm font-medium text-gray-500">Cidadão</Label>
            <p className="text-lg font-semibold text-gray-900">{processo.cidadao_nome}</p>
          </div>
          <div>
            <Label className="text-sm font-medium text-gray-500">Relator</Label>
            <p className="text-lg font-semibold text-gray-900">{processo.relator_nome}</p>
          </div>
          <div>
            <Label className="text-sm font-medium text-gray-500">Data Limite</Label>
            <p className="text-lg font-semibold text-gray-900">
              {formatDate(processo.data_limite)}
            </p>
          </div>
        </div>
      </div>

      {/* Parecer do Relator */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center space-x-2 mb-4">
          <Scale className="h-5 w-5 text-blue-600" />
          <h2 className="text-lg font-semibold text-gray-900">Parecer do Relator</h2>
        </div>
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <p className="text-gray-800 leading-relaxed">
            {processo.parecer_relator}
          </p>
        </div>
      </div>

      {/* Documentos */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center space-x-2 mb-4">
          <FileText className="h-5 w-5 text-green-600" />
          <h2 className="text-lg font-semibold text-gray-900">
            Documentos ({processo.documentos.length})
          </h2>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {processo.documentos.map((doc) => (
            <div key={doc.id} className="border border-gray-200 rounded-lg p-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-medium text-gray-900 capitalize">
                    {doc.tipo.replace('_', ' ')}
                  </h3>
                  <p className="text-sm text-gray-600">{doc.nome_arquivo}</p>
                  <span className={cn(
                    'inline-flex items-center px-2 py-1 rounded-full text-xs font-medium mt-1',
                    doc.status_validacao === 'aprovado' ? 'bg-green-100 text-green-800' :
                    doc.status_validacao === 'rejeitado' ? 'bg-red-100 text-red-800' :
                    'bg-yellow-100 text-yellow-800'
                  )}>
                    {doc.status_validacao}
                  </span>
                </div>
                <div className="flex space-x-2">
                  <Button size="sm" variant="outline">
                    <Eye className="h-4 w-4 mr-1" />
                    Ver
                  </Button>
                  <Button size="sm" variant="outline">
                    <Download className="h-4 w-4 mr-1" />
                    Download
                  </Button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Votos Existentes */}
      {processo.votos_existentes.length > 0 && (
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center space-x-2 mb-4">
            <Users className="h-5 w-5 text-purple-600" />
            <h2 className="text-lg font-semibold text-gray-900">
              Votos Registrados ({processo.votos_existentes.length})
            </h2>
          </div>
          <div className="space-y-4">
            {processo.votos_existentes.map((voto) => (
              <div key={voto.id} className="border border-gray-200 rounded-lg p-4">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center space-x-3 mb-2">
                      <h3 className="font-medium text-gray-900">{voto.julgador_nome}</h3>
                      <span className={cn(
                        'inline-flex items-center px-2 py-1 rounded-full text-xs font-medium',
                        getDecisaoColor(voto.decisao)
                      )}>
                        {voto.decisao === 'concordo' ? (
                          <>
                            <ThumbsUp className="h-3 w-3 mr-1" />
                            Concordo
                          </>
                        ) : (
                          <>
                            <ThumbsDown className="h-3 w-3 mr-1" />
                            Discordo
                          </>
                        )}
                      </span>
                      {voto.especializado && (
                        <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                          Especializado
                        </span>
                      )}
                    </div>
                    {voto.justificativa && (
                      <p className="text-sm text-gray-700 mb-2">
                        <strong>Justificativa:</strong> {voto.justificativa}
                      </p>
                    )}
                    <p className="text-xs text-gray-500">
                      Votado em {formatDate(voto.data_voto)}
                    </p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Interface de Votação */}
      {!jaVotou ? (
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center space-x-2 mb-6">
            <Scale className="h-5 w-5 text-indigo-600" />
            <h2 className="text-lg font-semibold text-gray-900">Registrar Voto</h2>
          </div>

          <div className="space-y-6">
            {/* Seleção de Decisão */}
            <div>
              <Label className="text-sm font-medium text-gray-700 mb-3 block">
                Sua Decisão *
              </Label>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <button
                  type="button"
                  onClick={() => setDecisao('concordo')}
                  className={cn(
                    'p-4 border-2 rounded-lg text-left transition-all',
                    decisao === 'concordo'
                      ? 'border-green-500 bg-green-50'
                      : 'border-gray-200 hover:border-green-300'
                  )}
                >
                  <div className="flex items-center space-x-3">
                    <ThumbsUp className={cn(
                      'h-6 w-6',
                      decisao === 'concordo' ? 'text-green-600' : 'text-gray-400'
                    )} />
                    <div>
                      <h3 className="font-semibold text-gray-900">Concordo</h3>
                      <p className="text-sm text-gray-600">
                        Concordo com o parecer do relator
                      </p>
                    </div>
                  </div>
                </button>

                <button
                  type="button"
                  onClick={() => setDecisao('discordo')}
                  className={cn(
                    'p-4 border-2 rounded-lg text-left transition-all',
                    decisao === 'discordo'
                      ? 'border-red-500 bg-red-50'
                      : 'border-gray-200 hover:border-red-300'
                  )}
                >
                  <div className="flex items-center space-x-3">
                    <ThumbsDown className={cn(
                      'h-6 w-6',
                      decisao === 'discordo' ? 'text-red-600' : 'text-gray-400'
                    )} />
                    <div>
                      <h3 className="font-semibold text-gray-900">Discordo</h3>
                      <p className="text-sm text-gray-600">
                        Discordo do parecer (justificativa obrigatória)
                      </p>
                    </div>
                  </div>
                </button>
              </div>
              {errors.decisao && (
                <p className="text-sm text-red-600 mt-1">{errors.decisao}</p>
              )}
            </div>

            {/* Justificativa */}
            <div>
              <Label className="text-sm font-medium text-gray-700 mb-2 block">
                Justificativa {decisao === 'discordo' && '*'}
              </Label>
              <textarea
                className={cn(
                  'w-full min-h-[120px] px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500',
                  errors.justificativa && 'border-red-500 focus:border-red-500 focus:ring-red-500'
                )}
                placeholder={
                  decisao === 'discordo'
                    ? 'Explique os motivos da sua discordância...'
                    : 'Observações adicionais (opcional)...'
                }
                value={justificativa}
                onChange={(e) => setJustificativa(e.target.value)}
              />
              {errors.justificativa && (
                <p className="text-sm text-red-600 mt-1">{errors.justificativa}</p>
              )}
            </div>

            {/* Botão de Submit */}
            <div className="flex justify-between items-center pt-4 border-t border-gray-200">
              <div className="text-sm text-gray-600">
                <Clock className="h-4 w-4 inline mr-1" />
                Tempo de análise será registrado automaticamente
              </div>
              <Button
                onClick={handleSubmitVote}
                disabled={submitting || !decisao}
                className="px-8"
              >
                {submitting ? 'Registrando...' : 'Registrar Voto'}
              </Button>
            </div>

            {errors.submit && (
              <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                <p className="text-sm text-red-800">{errors.submit}</p>
              </div>
            )}
          </div>
        </div>
      ) : (
        <div className="bg-green-50 border border-green-200 rounded-lg p-6">
          <div className="flex items-center space-x-2">
            <CheckCircle className="h-5 w-5 text-green-600" />
            <h3 className="text-lg font-semibold text-green-900">Voto Registrado</h3>
          </div>
          <p className="text-green-800 mt-2">
            Seu voto foi registrado com sucesso. O resultado final será definido quando o quórum for atingido.
          </p>
        </div>
      )}
    </div>
  )
}