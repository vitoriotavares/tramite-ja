'use client'

import { useState, useEffect } from 'react'
import { RelatorDashboard } from '@/components/RelatorDashboard'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Search, FileText, Clock, CheckCircle2, UserCheck } from 'lucide-react'

export default function RelatorPage() {
  const [relatorData, setRelatorData] = useState({
    nome: 'Dr. Ana Paula Silva',
    registro_oab: 'SP123456',
    especializacoes: ['velocidade', 'geral'],
    processos_ativos: 3,
    capacidade_maxima: 15
  })

  const [processos, setProcessos] = useState([
    {
      id: '1',
      codigo_acompanhamento: 'EPVB-E9GB-8WWO',
      tipo_infracao: 'velocidade',
      status: 'distribuido',
      cidadao_nome: 'João Silva',
      data_atribuicao: '2025-09-18T10:00:00Z',
      prazo_analise: '2025-09-25T10:00:00Z'
    },
    {
      id: '2',
      codigo_acompanhamento: 'MCP1-OIVN-XQ93',
      tipo_infracao: 'geral',
      status: 'em_analise',
      cidadao_nome: 'Maria Santos',
      data_atribuicao: '2025-09-15T14:30:00Z',
      prazo_analise: '2025-09-22T14:30:00Z',
      parecer_relator: 'Em análise dos documentos...'
    }
  ])

  const [searchTerm, setSearchTerm] = useState('')

  const filteredProcessos = processos.filter(processo =>
    processo.codigo_acompanhamento.toLowerCase().includes(searchTerm.toLowerCase()) ||
    processo.cidadao_nome.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'distribuido': return 'bg-yellow-100 text-yellow-800'
      case 'em_analise': return 'bg-blue-100 text-blue-800'
      case 'em_votacao': return 'bg-purple-100 text-purple-800'
      case 'decidido': return 'bg-green-100 text-green-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const getStatusText = (status: string) => {
    switch (status) {
      case 'distribuido': return 'Aguardando Análise'
      case 'em_analise': return 'Em Análise'
      case 'em_votacao': return 'Em Votação'
      case 'decidido': return 'Decidido'
      default: return status
    }
  }

  const getDaysUntilDeadline = (prazo: string) => {
    const hoje = new Date()
    const deadline = new Date(prazo)
    const diffTime = deadline.getTime() - hoje.getTime()
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
              <h1 className="text-3xl font-bold text-gray-900">
                Dashboard do Relator
              </h1>
              <p className="text-gray-600">
                {relatorData.nome} • {relatorData.registro_oab}
              </p>
            </div>
            <div className="mt-4 sm:mt-0 flex items-center space-x-2">
              <UserCheck className="h-5 w-5 text-green-600" />
              <span className="text-sm text-gray-600">
                {relatorData.processos_ativos}/{relatorData.capacidade_maxima} processos
              </span>
            </div>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Dashboard Component */}
        <div className="mb-8">
          <RelatorDashboard relatorId="1" />
        </div>

        {/* Processos Atribuídos */}
        <div className="bg-white rounded-lg shadow">
          <div className="p-6 border-b border-gray-200">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between">
              <h2 className="text-xl font-semibold text-gray-900">
                Processos Atribuídos
              </h2>
              <div className="mt-4 sm:mt-0 w-full sm:w-auto">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
                  <Input
                    placeholder="Buscar processos..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="pl-10 w-full sm:w-64"
                  />
                </div>
              </div>
            </div>
          </div>

          <div className="divide-y divide-gray-200">
            {filteredProcessos.map((processo) => {
              const diasRestantes = getDaysUntilDeadline(processo.prazo_analise)
              const isUrgent = diasRestantes <= 2

              return (
                <div key={processo.id} className="p-6 hover:bg-gray-50">
                  <div className="flex items-center justify-between">
                    <div className="flex-1">
                      <div className="flex items-center space-x-3 mb-2">
                        <h3 className="text-lg font-medium text-gray-900">
                          {processo.codigo_acompanhamento}
                        </h3>
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(processo.status)}`}>
                          {getStatusText(processo.status)}
                        </span>
                        {isUrgent && (
                          <span className="px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
                            URGENTE
                          </span>
                        )}
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm text-gray-600">
                        <div>
                          <span className="font-medium">Cidadão:</span> {processo.cidadao_nome}
                        </div>
                        <div>
                          <span className="font-medium">Tipo:</span> {processo.tipo_infracao}
                        </div>
                        <div className={isUrgent ? 'text-red-600 font-medium' : ''}>
                          <Clock className="inline h-4 w-4 mr-1" />
                          {diasRestantes > 0
                            ? `${diasRestantes} dias restantes`
                            : diasRestantes === 0
                              ? 'Vence hoje'
                              : `${Math.abs(diasRestantes)} dias atrasado`
                          }
                        </div>
                      </div>

                      {processo.parecer_relator && (
                        <div className="mt-3 p-3 bg-blue-50 rounded-lg">
                          <p className="text-sm text-blue-800">
                            <FileText className="inline h-4 w-4 mr-1" />
                            {processo.parecer_relator}
                          </p>
                        </div>
                      )}
                    </div>

                    <div className="ml-6 flex space-x-2">
                      {processo.status === 'distribuido' && (
                        <Button size="sm">
                          Iniciar Análise
                        </Button>
                      )}
                      {processo.status === 'em_analise' && (
                        <Button size="sm" variant="outline">
                          Finalizar Análise
                        </Button>
                      )}
                      <Button size="sm" variant="ghost">
                        Ver Detalhes
                      </Button>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>

          {filteredProcessos.length === 0 && (
            <div className="p-8 text-center">
              <FileText className="h-12 w-12 text-gray-300 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">
                {searchTerm ? 'Nenhum processo encontrado' : 'Nenhum processo atribuído'}
              </h3>
              <p className="text-gray-600">
                {searchTerm
                  ? 'Tente ajustar sua busca'
                  : 'Aguarde a distribuição de novos processos'
                }
              </p>
            </div>
          )}
        </div>

        {/* Estatísticas */}
        <div className="mt-8 grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="bg-white rounded-lg p-4 text-center shadow">
            <p className="text-2xl font-bold text-blue-600">{processos.length}</p>
            <p className="text-sm text-gray-600">Processos Ativos</p>
          </div>
          <div className="bg-white rounded-lg p-4 text-center shadow">
            <p className="text-2xl font-bold text-yellow-600">
              {processos.filter(p => p.status === 'distribuido').length}
            </p>
            <p className="text-sm text-gray-600">Aguardando Análise</p>
          </div>
          <div className="bg-white rounded-lg p-4 text-center shadow">
            <p className="text-2xl font-bold text-purple-600">
              {processos.filter(p => p.status === 'em_analise').length}
            </p>
            <p className="text-sm text-gray-600">Em Análise</p>
          </div>
          <div className="bg-white rounded-lg p-4 text-center shadow">
            <p className="text-2xl font-bold text-green-600">
              {processos.filter(p => getDaysUntilDeadline(p.prazo_analise) <= 2).length}
            </p>
            <p className="text-sm text-gray-600">Urgentes</p>
          </div>
        </div>
      </div>
    </div>
  )
}