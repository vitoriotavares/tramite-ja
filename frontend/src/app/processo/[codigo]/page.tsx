'use client'

import { useState, useEffect } from 'react'
import { useParams } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { ProcessTimeline } from '@/components/ProcessTimeline'
import { ArrowLeft, Download, FileText, AlertCircle } from 'lucide-react'

interface ProcessoData {
  id: string
  codigo_acompanhamento: string
  tipo_infracao: string
  status: string
  data_criacao: string
  data_limite: string
  cidadao_nome: string
  relator_nome?: string
  parecer_relator?: string
  decisao_final?: string
  documentos: any[]
  timeline: any[]
}

export default function ProcessoPage() {
  const params = useParams()
  const codigo = params.codigo as string
  const [processo, setProcesso] = useState<ProcessoData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchProcesso = async () => {
      try {
        const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/processos/${codigo}`)

        if (!response.ok) {
          throw new Error('Processo não encontrado')
        }

        const data = await response.json()
        setProcesso(data)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Erro ao carregar processo')
      } finally {
        setLoading(false)
      }
    }

    if (codigo) {
      fetchProcesso()
    }
  }, [codigo])

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

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Carregando processo...</p>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <AlertCircle className="h-16 w-16 text-red-500 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-gray-900 mb-2">Processo não encontrado</h1>
          <p className="text-gray-600 mb-6">{error}</p>
          <Button onClick={() => window.location.href = '/'}>
            <ArrowLeft className="h-4 w-4 mr-2" />
            Voltar ao início
          </Button>
        </div>
      </div>
    )
  }

  if (!processo) return null

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Button
                variant="ghost"
                onClick={() => window.location.href = '/'}
                className="p-2"
              >
                <ArrowLeft className="h-5 w-5" />
              </Button>
              <div>
                <h1 className="text-2xl font-bold text-gray-900">
                  Processo {processo.codigo_acompanhamento}
                </h1>
                <p className="text-gray-600">
                  {processo.cidadao_nome} • {processo.tipo_infracao}
                </p>
              </div>
            </div>
            <div className="flex items-center space-x-3">
              <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(processo.status)}`}>
                {getStatusText(processo.status)}
              </span>
            </div>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid lg:grid-cols-3 gap-8">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-6">
            {/* Status Card */}
            <div className="bg-white rounded-lg shadow p-6">
              <h2 className="text-lg font-semibold mb-4">Status do Processo</h2>
              <div className="grid md:grid-cols-2 gap-4">
                <div>
                  <label className="text-sm text-gray-500">Tipo de Infração</label>
                  <p className="font-medium">{processo.tipo_infracao}</p>
                </div>
                <div>
                  <label className="text-sm text-gray-500">Status Atual</label>
                  <p className="font-medium">{getStatusText(processo.status)}</p>
                </div>
                <div>
                  <label className="text-sm text-gray-500">Data de Criação</label>
                  <p className="font-medium">
                    {new Date(processo.data_criacao).toLocaleDateString('pt-BR')}
                  </p>
                </div>
                <div>
                  <label className="text-sm text-gray-500">Prazo Limite</label>
                  <p className="font-medium">
                    {new Date(processo.data_limite).toLocaleDateString('pt-BR')}
                  </p>
                </div>
              </div>
            </div>

            {/* Relator e Parecer */}
            {processo.relator_nome && (
              <div className="bg-white rounded-lg shadow p-6">
                <h2 className="text-lg font-semibold mb-4">Análise do Relator</h2>
                <div className="mb-4">
                  <label className="text-sm text-gray-500">Relator Responsável</label>
                  <p className="font-medium">{processo.relator_nome}</p>
                </div>
                {processo.parecer_relator && (
                  <div>
                    <label className="text-sm text-gray-500">Parecer</label>
                    <p className="mt-1 text-gray-700">{processo.parecer_relator}</p>
                  </div>
                )}
              </div>
            )}

            {/* Decisão Final */}
            {processo.decisao_final && (
              <div className="bg-white rounded-lg shadow p-6">
                <h2 className="text-lg font-semibold mb-4">Decisão Final</h2>
                <div className={`p-4 rounded-lg ${
                  processo.decisao_final === 'deferido'
                    ? 'bg-green-50 border border-green-200'
                    : 'bg-red-50 border border-red-200'
                }`}>
                  <p className={`font-semibold ${
                    processo.decisao_final === 'deferido' ? 'text-green-800' : 'text-red-800'
                  }`}>
                    {processo.decisao_final === 'deferido' ? 'RECURSO DEFERIDO' : 'RECURSO INDEFERIDO'}
                  </p>
                </div>
              </div>
            )}

            {/* Timeline */}
            <div className="bg-white rounded-lg shadow p-6">
              <h2 className="text-lg font-semibold mb-4">Histórico do Processo</h2>
              <ProcessTimeline processoId={processo.id} />
            </div>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Documentos */}
            <div className="bg-white rounded-lg shadow p-6">
              <h3 className="text-lg font-semibold mb-4">Documentos</h3>
              <div className="space-y-3">
                {processo.documentos.map((doc: any) => (
                  <div key={doc.id} className="flex items-center justify-between p-3 border border-gray-200 rounded-lg">
                    <div className="flex items-center space-x-3">
                      <FileText className="h-5 w-5 text-gray-400" />
                      <div>
                        <p className="font-medium text-sm">{doc.tipo}</p>
                        <p className="text-xs text-gray-500">{doc.status_validacao}</p>
                      </div>
                    </div>
                    <Button variant="ghost" size="sm">
                      <Download className="h-4 w-4" />
                    </Button>
                  </div>
                ))}
              </div>
            </div>

            {/* Informações Importantes */}
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-6">
              <h3 className="text-lg font-semibold text-blue-900 mb-3">Informações</h3>
              <div className="space-y-2 text-sm text-blue-800">
                <p>• Acompanhe o status em tempo real</p>
                <p>• Você será notificado sobre atualizações</p>
                <p>• Em caso de dúvidas, consulte o FAQ</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}