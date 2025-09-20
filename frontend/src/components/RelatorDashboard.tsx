'use client'

import { useState, useEffect } from 'react'
import { Button } from './ui/button'
import { Label } from './ui/label'
import { Input } from './ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select'
import { cn } from '@/lib/utils'
import {
  FileText,
  Clock,
  AlertTriangle,
  CheckCircle,
  Users,
  BarChart3,
  Calendar,
  TrendingUp,
  Filter,
  Search,
  Download,
  RefreshCw
} from 'lucide-react'

interface RelatorData {
  id: string
  nome: string
  registro_oab: string
  especializacoes: string[]
  processos_ativos: number
  capacidade_maxima: number
  disponivel: boolean
  carga_trabalho_percentual: number
  email: string
  data_cadastro: string
  disponivel_para_processo: boolean
  metricas_performance: any
  total_processos_historico: number
  processos_finalizados: number
}

interface ProcessoPendente {
  id: string
  codigo_acompanhamento: string
  tipo_infracao: string
  status: string
  cidadao_nome: string
  data_criacao: string
  data_limite: string
  dias_para_vencimento: number
  documentos_count: number
  urgente: boolean
}

interface EstatisticasRelator {
  total_processos_atribuidos: number
  processos_finalizados: number
  processos_pendentes: number
  processos_em_atraso: number
  tempo_medio_analise: number
  taxa_aprovacao: number
  carga_trabalho_percentual: number
  disponivel_para_novos: boolean
  metricas_performance: any
}

interface RelatorDashboardProps {
  relatorId: string
  className?: string
}

export function RelatorDashboard({ relatorId, className }: RelatorDashboardProps) {
  const [relatorData, setRelatorData] = useState<RelatorData | null>(null)
  const [processosPendentes, setProcessosPendentes] = useState<ProcessoPendente[]>([])
  const [estatisticas, setEstatisticas] = useState<EstatisticasRelator | null>(null)
  const [loading, setLoading] = useState(true)
  const [filtroStatus, setFiltroStatus] = useState<string>('')
  const [filtroTipo, setFiltroTipo] = useState<string>('')
  const [filtroUrgencia, setFiltroUrgencia] = useState<string>('')
  const [searchTerm, setSearchTerm] = useState('')

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        setLoading(true)

        // Mock data para desenvolvimento
        const mockRelatorData: RelatorData = {
          id: relatorId,
          nome: "Dr. Ana Paula Silva",
          registro_oab: "SP 123.456",
          especializacoes: ["velocidade", "estacionamento", "documentacao"],
          processos_ativos: 12,
          capacidade_maxima: 15,
          disponivel: true,
          carga_trabalho_percentual: 80,
          email: "ana.silva@oab.sp.gov.br",
          data_cadastro: "2024-01-15T10:00:00Z",
          disponivel_para_processo: true,
          metricas_performance: {},
          total_processos_historico: 156,
          processos_finalizados: 144
        }

        const mockEstatisticas: EstatisticasRelator = {
          total_processos_atribuidos: 156,
          processos_finalizados: 144,
          processos_pendentes: 12,
          processos_em_atraso: 2,
          tempo_medio_analise: 14,
          taxa_aprovacao: 68.5,
          carga_trabalho_percentual: 80,
          disponivel_para_novos: true,
          metricas_performance: {}
        }

        const mockProcessosPendentes: ProcessoPendente[] = [
          {
            id: "1",
            codigo_acompanhamento: "TRAM-2024-001",
            tipo_infracao: "velocidade",
            status: "distribuido",
            cidadao_nome: "João Santos Silva",
            data_criacao: "2024-09-15T10:00:00Z",
            data_limite: "2024-09-30T23:59:59Z",
            dias_para_vencimento: 10,
            documentos_count: 3,
            urgente: false
          },
          {
            id: "2",
            codigo_acompanhamento: "TRAM-2024-002",
            tipo_infracao: "estacionamento",
            status: "em_analise",
            cidadao_nome: "Maria Oliveira Costa",
            data_criacao: "2024-09-18T14:30:00Z",
            data_limite: "2024-09-25T23:59:59Z",
            dias_para_vencimento: 5,
            documentos_count: 2,
            urgente: true
          },
          {
            id: "3",
            codigo_acompanhamento: "TRAM-2024-003",
            tipo_infracao: "rodizio",
            status: "distribuido",
            cidadao_nome: "Carlos Eduardo Santos",
            data_criacao: "2024-09-19T09:15:00Z",
            data_limite: "2024-10-02T23:59:59Z",
            dias_para_vencimento: 12,
            documentos_count: 4,
            urgente: false
          },
          {
            id: "4",
            codigo_acompanhamento: "TRAM-2024-004",
            tipo_infracao: "velocidade",
            status: "em_votacao",
            cidadao_nome: "Ana Beatriz Lima",
            data_criacao: "2024-09-10T16:45:00Z",
            data_limite: "2024-09-22T23:59:59Z",
            dias_para_vencimento: 2,
            documentos_count: 5,
            urgente: true
          }
        ]

        // Simular delay de API
        await new Promise(resolve => setTimeout(resolve, 1000))

        setRelatorData(mockRelatorData)
        setProcessosPendentes(mockProcessosPendentes)
        setEstatisticas(mockEstatisticas)

      } catch (error) {
        console.error('Erro ao carregar dashboard:', error)
      } finally {
        setLoading(false)
      }
    }

    if (relatorId) {
      fetchDashboardData()
    }
  }, [relatorId])

  const filteredProcessos = processosPendentes.filter(processo => {
    const matchesSearch = processo.codigo_acompanhamento.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         processo.cidadao_nome.toLowerCase().includes(searchTerm.toLowerCase())

    const matchesStatus = filtroStatus === 'todos' || !filtroStatus || processo.status === filtroStatus
    const matchesTipo = filtroTipo === 'todos' || !filtroTipo || processo.tipo_infracao === filtroTipo
    const matchesUrgencia = filtroUrgencia === 'todos' || !filtroUrgencia ||
                           (filtroUrgencia === 'urgente' && processo.urgente) ||
                           (filtroUrgencia === 'normal' && !processo.urgente)

    return matchesSearch && matchesStatus && matchesTipo && matchesUrgencia
  })

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    })
  }

  const getUrgenciaColor = (dias: number) => {
    if (dias <= 0) return 'text-red-600 bg-red-100'
    if (dias <= 1) return 'text-red-600 bg-red-100'
    if (dias <= 3) return 'text-amber-600 bg-amber-100'
    return 'text-green-600 bg-green-100'
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'distribuido':
        return 'text-blue-600 bg-blue-100'
      case 'em_analise':
        return 'text-purple-600 bg-purple-100'
      case 'em_votacao':
        return 'text-indigo-600 bg-indigo-100'
      default:
        return 'text-gray-600 bg-gray-100'
    }
  }

  const getCargaColor = (percentual: number) => {
    if (percentual >= 90) return 'text-red-600 bg-red-100'
    if (percentual >= 70) return 'text-amber-600 bg-amber-100'
    return 'text-green-600 bg-green-100'
  }

  if (loading) {
    return (
      <div className={cn('w-full max-w-7xl mx-auto', className)}>
        <div className="animate-pulse">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="bg-white rounded-lg shadow p-6">
                <div className="h-4 bg-gray-200 rounded w-1/2 mb-2"></div>
                <div className="h-8 bg-gray-200 rounded w-1/3"></div>
              </div>
            ))}
          </div>
        </div>
      </div>
    )
  }

  if (!relatorData || !estatisticas) {
    return (
      <div className={cn('w-full max-w-7xl mx-auto', className)}>
        <div className="text-center py-12">
          <AlertTriangle className="mx-auto h-12 w-12 text-red-500 mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">
            Erro ao Carregar Dashboard
          </h3>
          <p className="text-gray-600">Não foi possível carregar os dados do relator.</p>
        </div>
      </div>
    )
  }

  return (
    <div className={cn('w-full max-w-7xl mx-auto space-y-6', className)}>
      {/* Header */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900 mb-2">
              Dashboard do Relator
            </h1>
            <div className="flex items-center space-x-4 text-sm text-gray-600">
              <span><strong>Nome:</strong> {relatorData.nome}</span>
              <span><strong>OAB:</strong> {relatorData.registro_oab}</span>
              <span><strong>Especializações:</strong> {relatorData.especializacoes.join(', ')}</span>
            </div>
          </div>
          <div className="flex items-center space-x-3">
            <Button variant="outline" size="sm">
              <Download className="h-4 w-4 mr-2" />
              Relatório
            </Button>
            <Button variant="outline" size="sm" onClick={() => window.location.reload()}>
              <RefreshCw className="h-4 w-4 mr-2" />
              Atualizar
            </Button>
          </div>
        </div>
      </div>

      {/* Métricas */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center">
            <div className="p-2 rounded-lg bg-blue-100">
              <FileText className="h-6 w-6 text-blue-600" />
            </div>
            <div className="ml-4">
              <h3 className="text-sm font-medium text-gray-500">Processos Pendentes</h3>
              <p className="text-2xl font-bold text-gray-900">{estatisticas.processos_pendentes}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center">
            <div className="p-2 rounded-lg bg-green-100">
              <CheckCircle className="h-6 w-6 text-green-600" />
            </div>
            <div className="ml-4">
              <h3 className="text-sm font-medium text-gray-500">Processos Finalizados</h3>
              <p className="text-2xl font-bold text-gray-900">{estatisticas.processos_finalizados}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center">
            <div className="p-2 rounded-lg bg-amber-100">
              <Clock className="h-6 w-6 text-amber-600" />
            </div>
            <div className="ml-4">
              <h3 className="text-sm font-medium text-gray-500">Tempo Médio (dias)</h3>
              <p className="text-2xl font-bold text-gray-900">{estatisticas.tempo_medio_analise}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex items-center">
            <div className={cn('p-2 rounded-lg', getCargaColor(estatisticas.carga_trabalho_percentual))}>
              <BarChart3 className="h-6 w-6" />
            </div>
            <div className="ml-4">
              <h3 className="text-sm font-medium text-gray-500">Carga de Trabalho</h3>
              <p className="text-2xl font-bold text-gray-900">{estatisticas.carga_trabalho_percentual}%</p>
            </div>
          </div>
        </div>
      </div>

      {/* Estatísticas Detalhadas */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white rounded-lg shadow-md p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            Estatísticas Gerais
          </h3>
          <div className="space-y-4">
            <div className="flex justify-between">
              <span className="text-gray-600">Total de Processos:</span>
              <span className="font-semibold">{estatisticas.total_processos_atribuidos}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Processos em Atraso:</span>
              <span className={cn(
                'font-semibold',
                estatisticas.processos_em_atraso > 0 ? 'text-red-600' : 'text-green-600'
              )}>
                {estatisticas.processos_em_atraso}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Taxa de Aprovação:</span>
              <span className="font-semibold">{estatisticas.taxa_aprovacao}%</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Disponível para Novos:</span>
              <span className={cn(
                'font-semibold',
                estatisticas.disponivel_para_novos ? 'text-green-600' : 'text-red-600'
              )}>
                {estatisticas.disponivel_para_novos ? 'Sim' : 'Não'}
              </span>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-md p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            Capacidade e Performance
          </h3>
          <div className="space-y-4">
            <div>
              <div className="flex justify-between text-sm mb-1">
                <span>Processos Ativos</span>
                <span>{relatorData.processos_ativos}/{relatorData.capacidade_maxima}</span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div
                  className={cn(
                    'h-2 rounded-full',
                    estatisticas.carga_trabalho_percentual >= 90 ? 'bg-red-500' :
                    estatisticas.carga_trabalho_percentual >= 70 ? 'bg-amber-500' : 'bg-green-500'
                  )}
                  style={{ width: `${Math.min(estatisticas.carga_trabalho_percentual, 100)}%` }}
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <Label className="text-xs text-gray-500">Desde</Label>
                <p className="text-sm font-medium">{formatDate(relatorData.data_cadastro)}</p>
              </div>
              <div>
                <Label className="text-xs text-gray-500">Status</Label>
                <p className={cn(
                  'text-sm font-medium',
                  relatorData.disponivel ? 'text-green-600' : 'text-red-600'
                )}>
                  {relatorData.disponivel ? 'Disponível' : 'Indisponível'}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Filtros e Lista de Processos */}
      <div className="bg-white rounded-lg shadow-md">
        <div className="p-6 border-b border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-gray-900">
              Processos Pendentes ({filteredProcessos.length})
            </h3>
          </div>

          {/* Filtros */}
          <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
            <div>
              <Label className="text-sm font-medium text-gray-700">Buscar</Label>
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                <Input
                  placeholder="Código ou cidadão..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="pl-10"
                />
              </div>
            </div>

            <div>
              <Label className="text-sm font-medium text-gray-700">Status</Label>
              <Select value={filtroStatus} onValueChange={setFiltroStatus}>
                <SelectTrigger>
                  <SelectValue placeholder="Todos" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="todos">Todos</SelectItem>
                  <SelectItem value="distribuido">Distribuído</SelectItem>
                  <SelectItem value="em_analise">Em Análise</SelectItem>
                  <SelectItem value="em_votacao">Em Votação</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div>
              <Label className="text-sm font-medium text-gray-700">Tipo</Label>
              <Select value={filtroTipo} onValueChange={setFiltroTipo}>
                <SelectTrigger>
                  <SelectValue placeholder="Todos" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="todos">Todos</SelectItem>
                  <SelectItem value="velocidade">Velocidade</SelectItem>
                  <SelectItem value="rodizio">Rodízio</SelectItem>
                  <SelectItem value="semaforo">Semáforo</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div>
              <Label className="text-sm font-medium text-gray-700">Urgência</Label>
              <Select value={filtroUrgencia} onValueChange={setFiltroUrgencia}>
                <SelectTrigger>
                  <SelectValue placeholder="Todos" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="todos">Todos</SelectItem>
                  <SelectItem value="urgente">Urgente</SelectItem>
                  <SelectItem value="normal">Normal</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="flex items-end">
              <Button
                variant="outline"
                onClick={() => {
                  setFiltroStatus('todos')
                  setFiltroTipo('todos')
                  setFiltroUrgencia('todos')
                  setSearchTerm('')
                }}
              >
                <Filter className="h-4 w-4 mr-2" />
                Limpar
              </Button>
            </div>
          </div>
        </div>

        {/* Lista de Processos */}
        <div className="p-6">
          {filteredProcessos.length === 0 ? (
            <div className="text-center py-8">
              <FileText className="mx-auto h-12 w-12 text-gray-400 mb-4" />
              <p className="text-gray-600">Nenhum processo encontrado com os filtros aplicados.</p>
            </div>
          ) : (
            <div className="space-y-4">
              {filteredProcessos.map((processo) => (
                <div
                  key={processo.id}
                  className={cn(
                    'border rounded-lg p-4 hover:bg-gray-50 transition-colors',
                    processo.urgente && 'border-red-200 bg-red-50'
                  )}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex-1">
                      <div className="flex items-center space-x-4">
                        <h4 className="font-semibold text-gray-900">
                          {processo.codigo_acompanhamento}
                        </h4>
                        <span className={cn(
                          'px-2 py-1 rounded-full text-xs font-medium',
                          getStatusColor(processo.status)
                        )}>
                          {processo.status.replace('_', ' ').toUpperCase()}
                        </span>
                        <span className={cn(
                          'px-2 py-1 rounded-full text-xs font-medium',
                          getUrgenciaColor(processo.dias_para_vencimento)
                        )}>
                          {processo.dias_para_vencimento <= 0 ? 'VENCIDO' :
                           processo.dias_para_vencimento === 1 ? '1 DIA' :
                           `${processo.dias_para_vencimento} DIAS`}
                        </span>
                      </div>

                      <div className="mt-2 text-sm text-gray-600">
                        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                          <div>
                            <strong>Cidadão:</strong> {processo.cidadao_nome}
                          </div>
                          <div>
                            <strong>Tipo:</strong> {processo.tipo_infracao.replace('_', ' ')}
                          </div>
                          <div>
                            <strong>Criado em:</strong> {formatDate(processo.data_criacao)}
                          </div>
                          <div>
                            <strong>Documentos:</strong> {processo.documentos_count}
                          </div>
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center space-x-2">
                      <Button size="sm" variant="outline">
                        Ver Detalhes
                      </Button>
                      <Button size="sm">
                        Analisar
                      </Button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}