'use client'

import { useState } from 'react'
import { VotingInterface } from '@/components/VotingInterface'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Search, Vote, Clock, CheckCircle2, AlertCircle } from 'lucide-react'

export default function JulgadorPage() {
  const [julgadorData] = useState({
    nome: 'Juiz Roberto Almeida',
    registro_profissional: 'MAG001234',
    especializacoes: ['velocidade', 'rodizio'],
    votos_pendentes: 2
  })

  const [processos] = useState([
    {
      id: '1',
      codigo_acompanhamento: 'LTAE-KNQK-EDSM',
      tipo_infracao: 'velocidade',
      status: 'em_votacao',
      cidadao_nome: 'Carlos Eduardo',
      relator_nome: 'Dra. Marina Costa',
      parecer_relator: 'A defesa alega problemas na calibração do radar. Documentos técnicos apresentados sustentam a alegação.',
      votos_atuais: 2,
      quorum_necessario: 3,
      ja_votou: false,
      data_limite_votacao: '2025-09-25T18:00:00Z'
    },
    {
      id: '2',
      codigo_acompanhamento: 'MTAX-FYEJ-GUUV',
      tipo_infracao: 'rodizio',
      status: 'em_votacao',
      cidadao_nome: 'Ana Maria Silva',
      relator_nome: 'Dr. Carlos Santos',
      parecer_relator: 'Defesa procedente. Cidadão comprovou estar em situação de emergência médica.',
      votos_atuais: 1,
      quorum_necessario: 3,
      ja_votou: true,
      meu_voto: 'concordo',
      data_limite_votacao: '2025-09-26T18:00:00Z'
    }
  ])

  const [searchTerm, setSearchTerm] = useState('')

  const filteredProcessos = processos.filter(processo =>
    processo.codigo_acompanhamento.toLowerCase().includes(searchTerm.toLowerCase()) ||
    processo.cidadao_nome.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const processosPendentes = processos.filter(p => !p.ja_votou)
  const processosVotados = processos.filter(p => p.ja_votou)

  const getTimeRemaining = (dataLimite: string) => {
    const agora = new Date()
    const limite = new Date(dataLimite)
    const diffTime = limite.getTime() - agora.getTime()
    const diffHours = Math.ceil(diffTime / (1000 * 60 * 60))

    if (diffHours <= 0) return 'Prazo vencido'
    if (diffHours < 24) return `${diffHours}h restantes`

    const diffDays = Math.ceil(diffHours / 24)
    return `${diffDays} dias restantes`
  }

  const isUrgent = (dataLimite: string) => {
    const agora = new Date()
    const limite = new Date(dataLimite)
    const diffTime = limite.getTime() - agora.getTime()
    const diffHours = diffTime / (1000 * 60 * 60)
    return diffHours <= 24
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">
                Dashboard do Julgador
              </h1>
              <p className="text-gray-600">
                {julgadorData.nome} • {julgadorData.registro_profissional}
              </p>
            </div>
            <div className="mt-4 sm:mt-0 flex items-center space-x-4">
              <div className="text-center">
                <p className="text-2xl font-bold text-orange-600">{processosPendentes.length}</p>
                <p className="text-xs text-gray-600">Votos Pendentes</p>
              </div>
              <div className="text-center">
                <p className="text-2xl font-bold text-green-600">{processosVotados.length}</p>
                <p className="text-xs text-gray-600">Votos Realizados</p>
              </div>
            </div>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Search */}
        <div className="mb-6">
          <div className="relative max-w-md">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
            <Input
              placeholder="Buscar processos..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10"
            />
          </div>
        </div>

        {/* Processos Pendentes */}
        {processosPendentes.length > 0 && (
          <div className="mb-8">
            <h2 className="text-xl font-semibold text-gray-900 mb-4 flex items-center">
              <AlertCircle className="h-5 w-5 text-orange-600 mr-2" />
              Votações Pendentes ({processosPendentes.length})
            </h2>
            <div className="space-y-4">
              {processosPendentes
                .filter(processo =>
                  processo.codigo_acompanhamento.toLowerCase().includes(searchTerm.toLowerCase()) ||
                  processo.cidadao_nome.toLowerCase().includes(searchTerm.toLowerCase())
                )
                .map((processo) => (
                <div key={processo.id} className="bg-white rounded-lg shadow hover:shadow-md transition-shadow">
                  <div className="p-6">
                    <div className="flex flex-col lg:flex-row lg:items-start lg:justify-between">
                      <div className="flex-1">
                        <div className="flex items-center space-x-3 mb-3">
                          <h3 className="text-lg font-medium text-gray-900">
                            {processo.codigo_acompanhamento}
                          </h3>
                          {isUrgent(processo.data_limite_votacao) && (
                            <span className="px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
                              URGENTE
                            </span>
                          )}
                        </div>

                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm text-gray-600 mb-4">
                          <div>
                            <span className="font-medium">Cidadão:</span> {processo.cidadao_nome}
                          </div>
                          <div>
                            <span className="font-medium">Tipo:</span> {processo.tipo_infracao}
                          </div>
                          <div>
                            <span className="font-medium">Relator:</span> {processo.relator_nome}
                          </div>
                          <div className={isUrgent(processo.data_limite_votacao) ? 'text-red-600 font-medium' : ''}>
                            <Clock className="inline h-4 w-4 mr-1" />
                            {getTimeRemaining(processo.data_limite_votacao)}
                          </div>
                        </div>

                        <div className="bg-blue-50 border-l-4 border-blue-400 p-4 mb-4">
                          <p className="text-sm text-blue-800">
                            <strong>Parecer do Relator:</strong> {processo.parecer_relator}
                          </p>
                        </div>

                        <div className="flex items-center space-x-4 text-sm">
                          <div className="flex items-center">
                            <Vote className="h-4 w-4 text-gray-400 mr-1" />
                            <span>{processo.votos_atuais}/{processo.quorum_necessario} votos</span>
                          </div>
                          <div className="bg-gray-200 rounded-full h-2 flex-1 max-w-32">
                            <div
                              className="bg-blue-600 h-2 rounded-full"
                              style={{ width: `${(processo.votos_atuais / processo.quorum_necessario) * 100}%` }}
                            />
                          </div>
                        </div>
                      </div>

                      <div className="mt-4 lg:mt-0 lg:ml-6">
                        <VotingInterface
                          processoId={processo.id}
                          julgadorId="1"
                        />
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Processos Já Votados */}
        <div>
          <h2 className="text-xl font-semibold text-gray-900 mb-4 flex items-center">
            <CheckCircle2 className="h-5 w-5 text-green-600 mr-2" />
            Votações Realizadas ({processosVotados.length})
          </h2>

          {processosVotados.length === 0 ? (
            <div className="bg-white rounded-lg shadow p-8 text-center">
              <Vote className="h-12 w-12 text-gray-300 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">
                Nenhuma votação realizada ainda
              </h3>
              <p className="text-gray-600">
                Seus votos aparecerão aqui após serem registrados
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {processosVotados
                .filter(processo =>
                  processo.codigo_acompanhamento.toLowerCase().includes(searchTerm.toLowerCase()) ||
                  processo.cidadao_nome.toLowerCase().includes(searchTerm.toLowerCase())
                )
                .map((processo) => (
                <div key={processo.id} className="bg-white rounded-lg shadow p-6">
                  <div className="flex items-center justify-between">
                    <div className="flex-1">
                      <div className="flex items-center space-x-3 mb-2">
                        <h3 className="text-lg font-medium text-gray-900">
                          {processo.codigo_acompanhamento}
                        </h3>
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                          processo.meu_voto === 'concordo'
                            ? 'bg-green-100 text-green-800'
                            : 'bg-red-100 text-red-800'
                        }`}>
                          {processo.meu_voto === 'concordo' ? 'CONCORDO' : 'DISCORDO'}
                        </span>
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm text-gray-600">
                        <div>
                          <span className="font-medium">Cidadão:</span> {processo.cidadao_nome}
                        </div>
                        <div>
                          <span className="font-medium">Tipo:</span> {processo.tipo_infracao}
                        </div>
                        <div>
                          <span className="font-medium">Progresso:</span> {processo.votos_atuais}/{processo.quorum_necessario} votos
                        </div>
                      </div>
                    </div>

                    <div className="ml-6">
                      <Button variant="ghost" size="sm">
                        Ver Detalhes
                      </Button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Estatísticas */}
        <div className="mt-8 grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="bg-white rounded-lg p-4 text-center shadow">
            <p className="text-2xl font-bold text-orange-600">{processosPendentes.length}</p>
            <p className="text-sm text-gray-600">Pendentes</p>
          </div>
          <div className="bg-white rounded-lg p-4 text-center shadow">
            <p className="text-2xl font-bold text-green-600">{processosVotados.length}</p>
            <p className="text-sm text-gray-600">Votados</p>
          </div>
          <div className="bg-white rounded-lg p-4 text-center shadow">
            <p className="text-2xl font-bold text-red-600">
              {processosPendentes.filter(p => isUrgent(p.data_limite_votacao)).length}
            </p>
            <p className="text-sm text-gray-600">Urgentes</p>
          </div>
          <div className="bg-white rounded-lg p-4 text-center shadow">
            <p className="text-2xl font-bold text-blue-600">{processos.length}</p>
            <p className="text-sm text-gray-600">Total</p>
          </div>
        </div>
      </div>
    </div>
  )
}