'use client'

import { useState, useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Search, Plus, Eye, FileText, Calendar } from 'lucide-react'

interface Processo {
  id: string
  codigo_acompanhamento: string
  tipo_infracao: string
  status: string
  data_criacao: string
  data_limite: string
  decisao_final?: string
}

export default function ProcessosPage() {
  const [processos, setProcessos] = useState<Processo[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')

  useEffect(() => {
    // Simulação - na implementação real, viria da API
    const mockProcessos: Processo[] = [
      {
        id: '1',
        codigo_acompanhamento: 'EPVB-E9GB-8WWO',
        tipo_infracao: 'velocidade',
        status: 'triagem',
        data_criacao: '2025-09-18T10:00:00Z',
        data_limite: '2025-10-17T10:00:00Z'
      },
      {
        id: '2',
        codigo_acompanhamento: 'MCP1-OIVN-XQ93',
        tipo_infracao: 'rodizio',
        status: 'distribuido',
        data_criacao: '2025-09-15T14:30:00Z',
        data_limite: '2025-10-14T14:30:00Z'
      },
      {
        id: '3',
        codigo_acompanhamento: 'VALF-U0FF-DQVM',
        tipo_infracao: 'semaforo',
        status: 'decidido',
        data_criacao: '2025-09-10T09:15:00Z',
        data_limite: '2025-10-09T09:15:00Z',
        decisao_final: 'deferido'
      }
    ]

    setTimeout(() => {
      setProcessos(mockProcessos)
      setLoading(false)
    }, 1000)
  }, [])

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'rascunho': return 'bg-gray-100 text-gray-800'
      case 'triagem': return 'bg-blue-100 text-blue-800'
      case 'distribuido': return 'bg-yellow-100 text-yellow-800'
      case 'em_analise': return 'bg-purple-100 text-purple-800'
      case 'em_votacao': return 'bg-orange-100 text-orange-800'
      case 'decidido': return 'bg-green-100 text-green-800'
      case 'rejeitado': return 'bg-red-100 text-red-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const getStatusText = (status: string) => {
    switch (status) {
      case 'rascunho': return 'Rascunho'
      case 'triagem': return 'Em Triagem'
      case 'distribuido': return 'Distribuído'
      case 'em_analise': return 'Em Análise'
      case 'em_votacao': return 'Em Votação'
      case 'decidido': return 'Decidido'
      case 'rejeitado': return 'Rejeitado'
      default: return status
    }
  }

  const getTipoInfracaoText = (tipo: string) => {
    switch (tipo) {
      case 'velocidade': return 'Excesso de Velocidade'
      case 'rodizio': return 'Rodízio de Veículos'
      case 'semaforo': return 'Avanço de Semáforo'
      case 'geral': return 'Infração Geral'
      default: return tipo
    }
  }

  const filteredProcessos = processos.filter(processo =>
    processo.codigo_acompanhamento.toLowerCase().includes(searchTerm.toLowerCase()) ||
    getTipoInfracaoText(processo.tipo_infracao).toLowerCase().includes(searchTerm.toLowerCase())
  )

  const getDaysRemaining = (dataLimite: string) => {
    const hoje = new Date()
    const limite = new Date(dataLimite)
    const diffTime = limite.getTime() - hoje.getTime()
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
    return diffDays
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Meus Processos</h1>
              <p className="text-gray-600">Acompanhe todos os seus recursos de trânsito</p>
            </div>
            <Button className="mt-4 sm:mt-0">
              <Plus className="h-4 w-4 mr-2" />
              Novo Processo
            </Button>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Search Bar */}
        <div className="mb-6">
          <div className="relative max-w-md">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
            <Input
              placeholder="Buscar por código ou tipo de infração..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10"
            />
          </div>
        </div>

        {/* Loading State */}
        {loading && (
          <div className="text-center py-12">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
            <p className="text-gray-600">Carregando processos...</p>
          </div>
        )}

        {/* Empty State */}
        {!loading && filteredProcessos.length === 0 && (
          <div className="text-center py-12">
            <FileText className="h-16 w-16 text-gray-300 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">
              {searchTerm ? 'Nenhum processo encontrado' : 'Nenhum processo ainda'}
            </h3>
            <p className="text-gray-600 mb-6">
              {searchTerm
                ? 'Tente ajustar sua busca'
                : 'Crie seu primeiro recurso de defesa de trânsito'
              }
            </p>
            {!searchTerm && (
              <Button>
                <Plus className="h-4 w-4 mr-2" />
                Criar Primeiro Processo
              </Button>
            )}
          </div>
        )}

        {/* Processes List */}
        {!loading && filteredProcessos.length > 0 && (
          <div className="space-y-4">
            {filteredProcessos.map((processo) => {
              const diasRestantes = getDaysRemaining(processo.data_limite)

              return (
                <div key={processo.id} className="bg-white rounded-lg shadow hover:shadow-md transition-shadow p-6">
                  <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between">
                    <div className="flex-1">
                      <div className="flex items-center space-x-3 mb-2">
                        <h3 className="text-lg font-semibold text-gray-900">
                          {processo.codigo_acompanhamento}
                        </h3>
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(processo.status)}`}>
                          {getStatusText(processo.status)}
                        </span>
                        {processo.decisao_final && (
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                            processo.decisao_final === 'deferido'
                              ? 'bg-green-100 text-green-800'
                              : 'bg-red-100 text-red-800'
                          }`}>
                            {processo.decisao_final === 'deferido' ? 'DEFERIDO' : 'INDEFERIDO'}
                          </span>
                        )}
                      </div>

                      <p className="text-gray-600 mb-2">
                        {getTipoInfracaoText(processo.tipo_infracao)}
                      </p>

                      <div className="flex items-center space-x-4 text-sm text-gray-500">
                        <div className="flex items-center">
                          <Calendar className="h-4 w-4 mr-1" />
                          Criado em {new Date(processo.data_criacao).toLocaleDateString('pt-BR')}
                        </div>
                        {processo.status !== 'decidido' && processo.status !== 'rejeitado' && (
                          <div className={`flex items-center ${diasRestantes <= 7 ? 'text-red-600' : 'text-gray-500'}`}>
                            <Calendar className="h-4 w-4 mr-1" />
                            {diasRestantes > 0
                              ? `${diasRestantes} dias restantes`
                              : diasRestantes === 0
                                ? 'Vence hoje'
                                : 'Prazo vencido'
                            }
                          </div>
                        )}
                      </div>
                    </div>

                    <div className="mt-4 sm:mt-0 sm:ml-6">
                      <Button
                        variant="outline"
                        onClick={() => window.location.href = `/processo/${processo.codigo_acompanhamento}`}
                      >
                        <Eye className="h-4 w-4 mr-2" />
                        Ver Detalhes
                      </Button>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        )}

        {/* Summary Stats */}
        {!loading && processos.length > 0 && (
          <div className="mt-8 grid grid-cols-1 md:grid-cols-4 gap-4">
            <div className="bg-white rounded-lg p-4 text-center">
              <p className="text-2xl font-bold text-blue-600">{processos.length}</p>
              <p className="text-sm text-gray-600">Total de Processos</p>
            </div>
            <div className="bg-white rounded-lg p-4 text-center">
              <p className="text-2xl font-bold text-yellow-600">
                {processos.filter(p => ['triagem', 'distribuido', 'em_analise', 'em_votacao'].includes(p.status)).length}
              </p>
              <p className="text-sm text-gray-600">Em Andamento</p>
            </div>
            <div className="bg-white rounded-lg p-4 text-center">
              <p className="text-2xl font-bold text-green-600">
                {processos.filter(p => p.decisao_final === 'deferido').length}
              </p>
              <p className="text-sm text-gray-600">Deferidos</p>
            </div>
            <div className="bg-white rounded-lg p-4 text-center">
              <p className="text-2xl font-bold text-red-600">
                {processos.filter(p => p.decisao_final === 'indeferido').length}
              </p>
              <p className="text-sm text-gray-600">Indeferidos</p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}