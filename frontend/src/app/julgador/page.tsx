'use client'

import { useState } from 'react'
import { VotingInterface } from '@/components/VotingInterface'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Separator } from '@/components/ui/separator'
import { Search, Vote, Clock, CheckCircle2, AlertCircle, Scale, User, FileText, Eye } from 'lucide-react'

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
    <div className="w-full h-full">
      {/* Header */}
      <div className="mb-6">
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

      <div className="space-y-6">
        {/* Search and Filters */}
        <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between">
          <div className="relative flex-1 max-w-md">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
            <Input
              placeholder="Buscar processos..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10"
            />
          </div>
          <Tabs defaultValue="pendentes" className="w-auto">
            <TabsList>
              <TabsTrigger value="pendentes">Pendentes ({processosPendentes.length})</TabsTrigger>
              <TabsTrigger value="votados">Votados ({processosVotados.length})</TabsTrigger>
            </TabsList>
          </Tabs>
        </div>

        <Tabs defaultValue="pendentes" className="w-full">
          <TabsContent value="pendentes" className="space-y-4">
            {processosPendentes.length === 0 ? (
              <div className="bg-white rounded-lg shadow p-8 text-center">
                <Vote className="h-12 w-12 text-gray-300 mx-auto mb-4" />
                <h3 className="text-lg font-medium text-gray-900 mb-2">
                  Nenhuma votação pendente
                </h3>
                <p className="text-gray-600">
                  Não há processos aguardando seu voto no momento
                </p>
              </div>
            ) : (
              <div className="grid gap-4">
                {processosPendentes
                  .filter(processo =>
                    processo.codigo_acompanhamento.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    processo.cidadao_nome.toLowerCase().includes(searchTerm.toLowerCase())
                  )
                  .map((processo) => (
                  <div key={processo.id} className="bg-white rounded-lg shadow hover:shadow-md transition-shadow">
                    <div className="p-6">
                      {/* Header with Status Badges */}
                      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
                        <div className="flex items-center gap-3">
                          <h3 className="text-lg font-semibold text-gray-900">
                            {processo.codigo_acompanhamento}
                          </h3>
                          <div className="flex gap-2">
                            {isUrgent(processo.data_limite_votacao) && (
                              <Badge variant="destructive">URGENTE</Badge>
                            )}
                            <Badge variant="outline">
                              {processo.tipo_infracao.replace('_', ' ')}
                            </Badge>
                          </div>
                        </div>
                        <div className="flex items-center gap-3">
                          <div className="text-sm text-gray-600">
                            <Vote className="inline h-4 w-4 mr-1" />
                            {processo.votos_atuais}/{processo.quorum_necessario}
                          </div>
                          <Sheet>
                            <SheetTrigger asChild>
                              <Button variant="default" size="sm">
                                <Scale className="h-4 w-4 mr-1" />
                                Votar
                              </Button>
                            </SheetTrigger>
                            <SheetContent className="w-full sm:max-w-4xl">
                              <SheetHeader>
                                <SheetTitle>Votação do Processo {processo.codigo_acompanhamento}</SheetTitle>
                              </SheetHeader>
                              <ScrollArea className="h-[calc(100vh-8rem)] mt-6">
                                <VotingInterface
                                  processoId={processo.id}
                                  julgadorId="1"
                                  className="max-w-none"
                                />
                              </ScrollArea>
                            </SheetContent>
                          </Sheet>
                        </div>
                      </div>

                      {/* Process Info Grid - Responsive Layout */}
                      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                        {/* Main Info */}
                        <div className="lg:col-span-2 space-y-4">
                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                            <div className="flex items-center gap-2">
                              <User className="h-4 w-4 text-gray-400" />
                              <span className="text-gray-600">Cidadão:</span>
                              <span className="font-medium">{processo.cidadao_nome}</span>
                            </div>
                            <div className="flex items-center gap-2">
                              <Scale className="h-4 w-4 text-gray-400" />
                              <span className="text-gray-600">Relator:</span>
                              <span className="font-medium">{processo.relator_nome}</span>
                            </div>
                          </div>

                          <Separator />

                          <div className="bg-blue-50 border-l-4 border-blue-400 p-4 rounded-r-lg">
                            <div className="flex items-start gap-2 mb-2">
                              <FileText className="h-4 w-4 text-blue-600 mt-0.5" />
                              <span className="text-sm font-medium text-blue-900">Parecer do Relator</span>
                            </div>
                            <p className="text-sm text-blue-800 leading-relaxed">
                              {processo.parecer_relator}
                            </p>
                          </div>
                        </div>

                        {/* Status Panel */}
                        <div className="space-y-4">
                          <div className="bg-gray-50 rounded-lg p-4">
                            <h4 className="text-sm font-medium text-gray-900 mb-3">Status da Votação</h4>
                            <div className="space-y-3">
                              <div className="flex justify-between text-sm">
                                <span className="text-gray-600">Progresso</span>
                                <span className="font-medium">
                                  {Math.round((processo.votos_atuais / processo.quorum_necessario) * 100)}%
                                </span>
                              </div>
                              <div className="bg-gray-200 rounded-full h-2">
                                <div
                                  className="bg-blue-600 h-2 rounded-full transition-all"
                                  style={{ width: `${(processo.votos_atuais / processo.quorum_necessario) * 100}%` }}
                                />
                              </div>
                              <div className={`flex items-center gap-2 text-sm ${
                                isUrgent(processo.data_limite_votacao) ? 'text-red-600' : 'text-gray-600'
                              }`}>
                                <Clock className="h-4 w-4" />
                                <span>{getTimeRemaining(processo.data_limite_votacao)}</span>
                              </div>
                            </div>
                          </div>

                          <Button variant="outline" size="sm" className="w-full">
                            <Eye className="h-4 w-4 mr-1" />
                            Ver Documentos
                          </Button>
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </TabsContent>

          <TabsContent value="votados" className="space-y-4">
            {processosVotados.length === 0 ? (
              <div className="bg-white rounded-lg shadow p-8 text-center">
                <CheckCircle2 className="h-12 w-12 text-gray-300 mx-auto mb-4" />
                <h3 className="text-lg font-medium text-gray-900 mb-2">
                  Nenhuma votação realizada ainda
                </h3>
                <p className="text-gray-600">
                  Seus votos aparecerão aqui após serem registrados
                </p>
              </div>
            ) : (
              <div className="grid gap-4">
                {processosVotados
                  .filter(processo =>
                    processo.codigo_acompanhamento.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    processo.cidadao_nome.toLowerCase().includes(searchTerm.toLowerCase())
                  )
                  .map((processo) => (
                  <div key={processo.id} className="bg-white rounded-lg shadow hover:shadow-md transition-shadow">
                    <div className="p-6">
                      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
                        <div className="flex items-center gap-3">
                          <h3 className="text-lg font-semibold text-gray-900">
                            {processo.codigo_acompanhamento}
                          </h3>
                          <div className="flex gap-2">
                            <Badge variant={processo.meu_voto === 'concordo' ? 'default' : 'destructive'}>
                              {processo.meu_voto === 'concordo' ? 'CONCORDO' : 'DISCORDO'}
                            </Badge>
                            <Badge variant="outline">
                              {processo.tipo_infracao.replace('_', ' ')}
                            </Badge>
                          </div>
                        </div>
                        <div className="flex items-center gap-3">
                          <div className="text-sm text-gray-600">
                            <Vote className="inline h-4 w-4 mr-1" />
                            {processo.votos_atuais}/{processo.quorum_necessario}
                          </div>
                          <Sheet>
                            <SheetTrigger asChild>
                              <Button variant="outline" size="sm">
                                <Eye className="h-4 w-4 mr-1" />
                                Ver Detalhes
                              </Button>
                            </SheetTrigger>
                            <SheetContent className="w-full sm:max-w-4xl">
                              <SheetHeader>
                                <SheetTitle>Detalhes do Processo {processo.codigo_acompanhamento}</SheetTitle>
                              </SheetHeader>
                              <ScrollArea className="h-[calc(100vh-8rem)] mt-6">
                                <VotingInterface
                                  processoId={processo.id}
                                  julgadorId="1"
                                  className="max-w-none"
                                />
                              </ScrollArea>
                            </SheetContent>
                          </Sheet>
                        </div>
                      </div>

                      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm">
                        <div className="flex items-center gap-2">
                          <User className="h-4 w-4 text-gray-400" />
                          <span className="text-gray-600">Cidadão:</span>
                          <span className="font-medium">{processo.cidadao_nome}</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <Scale className="h-4 w-4 text-gray-400" />
                          <span className="text-gray-600">Relator:</span>
                          <span className="font-medium">{processo.relator_nome}</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <Vote className="h-4 w-4 text-gray-400" />
                          <span className="text-gray-600">Progresso:</span>
                          <span className="font-medium">{processo.votos_atuais}/{processo.quorum_necessario} votos</span>
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </TabsContent>
        </Tabs>

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