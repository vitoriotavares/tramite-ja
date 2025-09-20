'use client'

import { useState, useEffect } from 'react'
import { cn } from '@/lib/utils'
import { Label } from './ui/label'
import {
  FileText,
  Search,
  UserCheck,
  Scale,
  Vote,
  CheckCircle,
  XCircle,
  Clock,
  AlertTriangle,
  CalendarDays
} from 'lucide-react'

interface ProcessTimelineStep {
  id: string
  status: 'rascunho' | 'triagem' | 'distribuido' | 'em_analise' | 'em_votacao' | 'decidido' | 'rejeitado'
  title: string
  description: string
  date?: string
  completed: boolean
  current: boolean
  icon: React.ReactNode
  details?: string
}

interface ProcessData {
  id: string
  codigo_acompanhamento: string
  tipo_infracao: string
  status: string
  data_criacao: string
  data_limite: string
  data_decisao?: string
  decisao_final?: string
  parecer_relator?: string
  justificativa_rejeicao?: string
  documentos?: any[]
  votos?: any[]
}

interface ProcessTimelineProps {
  codigoAcompanhamento: string
  className?: string
}

const STATUS_STEPS: ProcessTimelineStep[] = [
  {
    id: 'rascunho',
    status: 'rascunho',
    title: 'Processo Criado',
    description: 'Processo foi iniciado e está aguardando documentos',
    completed: false,
    current: false,
    icon: <FileText className="h-5 w-5" />
  },
  {
    id: 'triagem',
    status: 'triagem',
    title: 'Triagem Inicial',
    description: 'Documentos estão sendo verificados pela equipe técnica',
    completed: false,
    current: false,
    icon: <Search className="h-5 w-5" />
  },
  {
    id: 'distribuido',
    status: 'distribuido',
    title: 'Distribuído para Relator',
    description: 'Processo foi designado para um relator especializado',
    completed: false,
    current: false,
    icon: <UserCheck className="h-5 w-5" />
  },
  {
    id: 'em_analise',
    status: 'em_analise',
    title: 'Análise Jurídica',
    description: 'Relator está analisando os méritos da defesa',
    completed: false,
    current: false,
    icon: <Scale className="h-5 w-5" />
  },
  {
    id: 'em_votacao',
    status: 'em_votacao',
    title: 'Votação Colegiada',
    description: 'Julgadores estão votando sobre a decisão',
    completed: false,
    current: false,
    icon: <Vote className="h-5 w-5" />
  },
  {
    id: 'decidido',
    status: 'decidido',
    title: 'Decisão Final',
    description: 'Processo finalizado com decisão colegiada',
    completed: false,
    current: false,
    icon: <CheckCircle className="h-5 w-5" />
  }
]

export function ProcessTimeline({ codigoAcompanhamento, className }: ProcessTimelineProps) {
  const [processData, setProcessData] = useState<ProcessData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchProcessData = async () => {
      try {
        setLoading(true)

        // Simular chamada à API de acompanhamento
        const response = await fetch(`/api/v1/acompanhamento/${codigoAcompanhamento}`)

        if (!response.ok) {
          if (response.status === 404) {
            throw new Error('Processo não encontrado. Verifique o código de acompanhamento.')
          }
          throw new Error('Erro ao carregar dados do processo')
        }

        const data = await response.json()
        setProcessData(data.processo)

      } catch (err) {
        setError(err instanceof Error ? err.message : 'Erro desconhecido')
      } finally {
        setLoading(false)
      }
    }

    if (codigoAcompanhamento) {
      fetchProcessData()
    }
  }, [codigoAcompanhamento])

  const getTimelineSteps = (status: string): ProcessTimelineStep[] => {
    const steps = [...STATUS_STEPS]

    // Se foi rejeitado, criar step especial
    if (status === 'rejeitado') {
      return [
        ...steps.slice(0, 2), // rascunho e triagem
        {
          id: 'rejeitado',
          status: 'rejeitado',
          title: 'Processo Rejeitado',
          description: 'Processo foi rejeitado na triagem',
          completed: true,
          current: true,
          icon: <XCircle className="h-5 w-5" />
        }
      ]
    }

    // Marcar steps como completos/atual baseado no status
    const statusOrder = ['rascunho', 'triagem', 'distribuido', 'em_analise', 'em_votacao', 'decidido']
    const currentIndex = statusOrder.indexOf(status)

    return steps.map((step, index) => ({
      ...step,
      completed: index < currentIndex,
      current: index === currentIndex
    }))
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

  const getDaysRemaining = (dataLimite: string) => {
    const now = new Date()
    const limite = new Date(dataLimite)
    const diffTime = limite.getTime() - now.getTime()
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
    return diffDays
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'decidido':
        return 'text-green-600 bg-green-100'
      case 'rejeitado':
        return 'text-red-600 bg-red-100'
      case 'em_votacao':
        return 'text-blue-600 bg-blue-100'
      case 'em_analise':
        return 'text-purple-600 bg-purple-100'
      case 'distribuido':
        return 'text-indigo-600 bg-indigo-100'
      case 'triagem':
        return 'text-yellow-600 bg-yellow-100'
      default:
        return 'text-gray-600 bg-gray-100'
    }
  }

  const getDecisaoLabel = (decisao: string) => {
    switch (decisao) {
      case 'deferido':
        return { label: 'Deferido', color: 'text-green-600 bg-green-100' }
      case 'indeferido':
        return { label: 'Indeferido', color: 'text-red-600 bg-red-100' }
      default:
        return { label: 'Pendente', color: 'text-gray-600 bg-gray-100' }
    }
  }

  if (loading) {
    return (
      <div className={cn('w-full max-w-4xl mx-auto', className)}>
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="animate-pulse">
            <div className="h-6 bg-gray-200 rounded w-1/4 mb-4"></div>
            <div className="space-y-4">
              {[1, 2, 3, 4].map((i) => (
                <div key={i} className="flex items-center space-x-4">
                  <div className="h-10 w-10 bg-gray-200 rounded-full"></div>
                  <div className="flex-1">
                    <div className="h-4 bg-gray-200 rounded w-1/3 mb-2"></div>
                    <div className="h-3 bg-gray-200 rounded w-2/3"></div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className={cn('w-full max-w-4xl mx-auto', className)}>
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="text-center">
            <AlertTriangle className="mx-auto h-12 w-12 text-red-500 mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">
              Erro ao Carregar Processo
            </h3>
            <p className="text-gray-600">{error}</p>
          </div>
        </div>
      </div>
    )
  }

  if (!processData) {
    return null
  }

  const timelineSteps = getTimelineSteps(processData.status)
  const daysRemaining = getDaysRemaining(processData.data_limite)
  const decisao = processData.decisao_final ? getDecisaoLabel(processData.decisao_final) : null

  return (
    <div className={cn('w-full max-w-4xl mx-auto', className)}>
      <div className="bg-white rounded-lg shadow-md overflow-hidden">
        {/* Header */}
        <div className="bg-blue-50 border-b border-blue-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900 mb-2">
                Acompanhamento do Processo
              </h1>
              <p className="text-gray-600">
                Código: <span className="font-mono font-semibold">{processData.codigo_acompanhamento}</span>
              </p>
            </div>
            <div className="text-right">
              <span className={cn(
                'inline-flex items-center px-3 py-1 rounded-full text-sm font-medium',
                getStatusColor(processData.status)
              )}>
                {processData.status === 'decidido' && decisao ? decisao.label : processData.status.replace('_', ' ').toUpperCase()}
              </span>
            </div>
          </div>
        </div>

        {/* Informações do Processo */}
        <div className="p-6 border-b border-gray-200">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div>
              <Label className="text-sm font-medium text-gray-500">Tipo de Infração</Label>
              <p className="text-lg font-semibold text-gray-900 capitalize">
                {processData.tipo_infracao.replace('_', ' ')}
              </p>
            </div>
            <div>
              <Label className="text-sm font-medium text-gray-500">Data de Criação</Label>
              <p className="text-lg font-semibold text-gray-900">
                {formatDate(processData.data_criacao)}
              </p>
            </div>
            <div>
              <Label className="text-sm font-medium text-gray-500">Prazo Limite</Label>
              <div className="flex items-center space-x-2">
                <CalendarDays className="h-4 w-4 text-gray-400" />
                <p className={cn(
                  'text-lg font-semibold',
                  daysRemaining <= 1 ? 'text-red-600' :
                  daysRemaining <= 3 ? 'text-amber-600' : 'text-gray-900'
                )}>
                  {daysRemaining > 0 ? `${daysRemaining} dias restantes` : 'Vencido'}
                </p>
              </div>
            </div>
          </div>

          {processData.status === 'decidido' && decisao && (
            <div className="mt-6 p-4 bg-gray-50 rounded-lg">
              <div className="flex items-center space-x-2 mb-2">
                <CheckCircle className="h-5 w-5 text-green-500" />
                <h3 className="font-semibold text-gray-900">Decisão Final</h3>
              </div>
              <div className="flex items-center space-x-4">
                <span className={cn(
                  'inline-flex items-center px-3 py-1 rounded-full text-sm font-medium',
                  decisao.color
                )}>
                  {decisao.label}
                </span>
                {processData.data_decisao && (
                  <span className="text-sm text-gray-600">
                    Decidido em {formatDate(processData.data_decisao)}
                  </span>
                )}
              </div>
              {processData.parecer_relator && (
                <p className="mt-2 text-sm text-gray-700">
                  <strong>Parecer:</strong> {processData.parecer_relator}
                </p>
              )}
            </div>
          )}

          {processData.status === 'rejeitado' && processData.justificativa_rejeicao && (
            <div className="mt-6 p-4 bg-red-50 border border-red-200 rounded-lg">
              <div className="flex items-center space-x-2 mb-2">
                <XCircle className="h-5 w-5 text-red-500" />
                <h3 className="font-semibold text-red-900">Motivo da Rejeição</h3>
              </div>
              <p className="text-sm text-red-800">
                {processData.justificativa_rejeicao}
              </p>
            </div>
          )}
        </div>

        {/* Timeline */}
        <div className="p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-6">
            Andamento do Processo
          </h2>

          <div className="space-y-6">
            {timelineSteps.map((step, index) => (
              <div key={step.id} className="flex items-start space-x-4">
                {/* Icon */}
                <div className={cn(
                  'flex items-center justify-center w-10 h-10 rounded-full border-2',
                  step.completed
                    ? 'bg-green-100 border-green-500 text-green-600'
                    : step.current
                    ? 'bg-blue-100 border-blue-500 text-blue-600'
                    : 'bg-gray-100 border-gray-300 text-gray-400'
                )}>
                  {step.completed ? <CheckCircle className="h-5 w-5" /> :
                   step.current ? <Clock className="h-5 w-5" /> : step.icon}
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <h3 className={cn(
                      'text-sm font-medium',
                      step.completed ? 'text-green-900' :
                      step.current ? 'text-blue-900' : 'text-gray-500'
                    )}>
                      {step.title}
                    </h3>
                    {step.current && (
                      <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                        Atual
                      </span>
                    )}
                  </div>
                  <p className="text-sm text-gray-600 mt-1">
                    {step.description}
                  </p>
                  {step.details && (
                    <p className="text-xs text-gray-500 mt-1">
                      {step.details}
                    </p>
                  )}
                </div>

                {/* Line connector */}
                {index < timelineSteps.length - 1 && (
                  <div className="absolute left-5 mt-10 w-0.5 h-6 bg-gray-300" />
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Informações Adicionais */}
        <div className="bg-gray-50 p-6">
          <div className="text-center text-sm text-gray-600">
            <p>
              Para dúvidas ou informações adicionais, entre em contato pelo email:{' '}
              <a href="mailto:contato@tramiteja.com.br" className="text-blue-600 hover:underline">
                contato@tramiteja.com.br
              </a>
            </p>
            <p className="mt-1">
              Última atualização: {formatDate(new Date().toISOString())}
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}