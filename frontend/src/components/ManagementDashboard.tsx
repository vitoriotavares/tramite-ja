'use client'

import { useState, useEffect } from 'react'
import { Button } from './ui/button'
import { Label } from './ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select'
import { cn } from '@/lib/utils'
import {
  BarChart3,
  TrendingUp,
  TrendingDown,
  Users,
  FileText,
  Clock,
  CheckCircle,
  AlertTriangle,
  Calendar,
  Download,
  RefreshCw,
  Filter,
  Activity
} from 'lucide-react'

interface DashboardMetricas {
  processos: {
    total: number
    pendentes: number
    finalizados: number
    em_atraso: number
    taxa_conclusao: number
    tempo_medio_conclusao: number
  }
  relatores: {
    total: number
    ativos: number
    disponivel_capacidade: number
    carga_media: number
    distribuicao_especializacoes: { [key: string]: number }
  }
  julgadores: {
    total: number
    ativos_ultimo_mes: number
    votos_ultimo_mes: number
    tempo_medio_voto: number
  }
  performance: {
    processos_por_dia: { data: string; total: number }[]
    resolucao_por_tipo: { tipo: string; total: number; media_dias: number }[]
    tendencia_volume: number
    tendencia_tempo: number
  }
  alertas: {
    processos_vencidos: number
    relatores_sobrecarregados: number
    documentos_pendentes: number
    votacoes_travadas: number
  }
}

interface ManagementDashboardProps {
  className?: string
}

export function ManagementDashboard({ className }: ManagementDashboardProps) {
  const [metricas, setMetricas] = useState<DashboardMetricas | null>(null)
  const [loading, setLoading] = useState(true)
  const [periodo, setPeriodo] = useState('30') // dias
  const [tipoMetrica, setTipoMetrica] = useState('geral')

  useEffect(() => {
    const fetchMetricas = async () => {
      try {
        setLoading(true)

        const params = new URLSearchParams({
          periodo: periodo,
          tipo: tipoMetrica
        })

        const response = await fetch(`/api/v1/dashboard/metricas?${params}`, {
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('token')}`
          }
        })

        if (!response.ok) {
          throw new Error('Erro ao carregar métricas')
        }

        const data = await response.json()
        setMetricas(data)

      } catch (error) {
        console.error('Erro ao carregar métricas:', error)
      } finally {
        setLoading(false)
      }
    }

    fetchMetricas()
  }, [periodo, tipoMetrica])

  const formatNumber = (num: number) => {
    return new Intl.NumberFormat('pt-BR').format(num)
  }

  const formatPercentage = (num: number) => {
    return `${num.toFixed(1)}%`
  }

  const getTendenciaColor = (valor: number) => {
    if (valor > 0) return 'text-green-600'
    if (valor < 0) return 'text-red-600'
    return 'text-gray-600'
  }

  const getTendenciaIcon = (valor: number) => {
    if (valor > 0) return <TrendingUp className="h-4 w-4" />
    if (valor < 0) return <TrendingDown className="h-4 w-4" />
    return <Activity className="h-4 w-4" />
  }

  const getAlertLevel = (count: number, threshold: number) => {
    if (count === 0) return 'text-green-600 bg-green-100'
    if (count <= threshold) return 'text-amber-600 bg-amber-100'
    return 'text-red-600 bg-red-100'
  }

  if (loading) {
    return (
      <div className={cn('w-full max-w-7xl mx-auto', className)}>
        <div className="animate-pulse space-y-6">
          <div className="bg-white rounded-lg shadow-md p-6">
            <div className="h-6 bg-gray-200 rounded w-1/4 mb-4"></div>
            <div className="grid grid-cols-4 gap-6">
              {[1, 2, 3, 4].map((i) => (
                <div key={i} className="space-y-2">
                  <div className="h-4 bg-gray-200 rounded w-3/4"></div>
                  <div className="h-8 bg-gray-200 rounded w-1/2"></div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    )
  }

  if (!metricas) {
    return (
      <div className={cn('w-full max-w-7xl mx-auto', className)}>
        <div className="text-center py-12">
          <AlertTriangle className="mx-auto h-12 w-12 text-red-500 mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">
            Erro ao Carregar Dashboard
          </h3>
          <p className="text-gray-600">Não foi possível carregar as métricas do sistema.</p>
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
              Dashboard de Gestão
            </h1>
            <p className="text-gray-600">
              Visão geral do sistema TrâmiteJá
            </p>
          </div>
          <div className="flex items-center space-x-3">
            <Select value={periodo} onValueChange={setPeriodo}>
              <SelectTrigger className="w-40">
                <SelectValue placeholder="Período" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="7">Últimos 7 dias</SelectItem>
                <SelectItem value="30">Últimos 30 dias</SelectItem>
                <SelectItem value="90">Últimos 90 dias</SelectItem>
                <SelectItem value="365">Último ano</SelectItem>
              </SelectContent>
            </Select>
            <Button variant="outline" size="sm">
              <Download className="h-4 w-4 mr-2" />
              Exportar
            </Button>
            <Button variant="outline" size="sm" onClick={() => window.location.reload()}>
              <RefreshCw className="h-4 w-4 mr-2" />
              Atualizar
            </Button>
          </div>
        </div>
      </div>

      {/* Alertas */}
      {(metricas.alertas.processos_vencidos > 0 ||
        metricas.alertas.relatores_sobrecarregados > 0 ||
        metricas.alertas.documentos_pendentes > 10 ||
        metricas.alertas.votacoes_travadas > 0) && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-6">
          <div className="flex items-center space-x-2 mb-4">
            <AlertTriangle className="h-5 w-5 text-red-600" />
            <h2 className="text-lg font-semibold text-red-900">Alertas do Sistema</h2>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            {metricas.alertas.processos_vencidos > 0 && (
              <div className="bg-white rounded-lg p-4 border border-red-200">
                <h3 className="font-medium text-red-900">Processos Vencidos</h3>
                <p className="text-2xl font-bold text-red-600">{metricas.alertas.processos_vencidos}</p>
              </div>
            )}
            {metricas.alertas.relatores_sobrecarregados > 0 && (
              <div className="bg-white rounded-lg p-4 border border-red-200">
                <h3 className="font-medium text-red-900">Relatores Sobrecarregados</h3>
                <p className="text-2xl font-bold text-red-600">{metricas.alertas.relatores_sobrecarregados}</p>
              </div>
            )}
            {metricas.alertas.documentos_pendentes > 10 && (
              <div className="bg-white rounded-lg p-4 border border-amber-200">
                <h3 className="font-medium text-amber-900">Documentos Pendentes</h3>
                <p className="text-2xl font-bold text-amber-600">{metricas.alertas.documentos_pendentes}</p>
              </div>
            )}
            {metricas.alertas.votacoes_travadas > 0 && (
              <div className="bg-white rounded-lg p-4 border border-red-200">
                <h3 className="font-medium text-red-900">Votações Travadas</h3>
                <p className="text-2xl font-bold text-red-600">{metricas.alertas.votacoes_travadas}</p>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Métricas Principais de Processos */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-6">Processos</h2>
        <div className="grid grid-cols-1 md:grid-cols-6 gap-6">
          <div className="text-center">
            <div className="p-3 rounded-lg bg-blue-100 inline-block mb-2">
              <FileText className="h-6 w-6 text-blue-600" />
            </div>
            <h3 className="text-sm font-medium text-gray-500">Total</h3>
            <p className="text-2xl font-bold text-gray-900">{formatNumber(metricas.processos.total)}</p>
          </div>

          <div className="text-center">
            <div className="p-3 rounded-lg bg-amber-100 inline-block mb-2">
              <Clock className="h-6 w-6 text-amber-600" />
            </div>
            <h3 className="text-sm font-medium text-gray-500">Pendentes</h3>
            <p className="text-2xl font-bold text-gray-900">{formatNumber(metricas.processos.pendentes)}</p>
          </div>

          <div className="text-center">
            <div className="p-3 rounded-lg bg-green-100 inline-block mb-2">
              <CheckCircle className="h-6 w-6 text-green-600" />
            </div>
            <h3 className="text-sm font-medium text-gray-500">Finalizados</h3>
            <p className="text-2xl font-bold text-gray-900">{formatNumber(metricas.processos.finalizados)}</p>
          </div>

          <div className="text-center">
            <div className="p-3 rounded-lg bg-red-100 inline-block mb-2">
              <AlertTriangle className="h-6 w-6 text-red-600" />
            </div>
            <h3 className="text-sm font-medium text-gray-500">Em Atraso</h3>
            <p className="text-2xl font-bold text-gray-900">{formatNumber(metricas.processos.em_atraso)}</p>
          </div>

          <div className="text-center">
            <div className="p-3 rounded-lg bg-purple-100 inline-block mb-2">
              <BarChart3 className="h-6 w-6 text-purple-600" />
            </div>
            <h3 className="text-sm font-medium text-gray-500">Taxa Conclusão</h3>
            <p className="text-2xl font-bold text-gray-900">{formatPercentage(metricas.processos.taxa_conclusao)}</p>
          </div>

          <div className="text-center">
            <div className="p-3 rounded-lg bg-indigo-100 inline-block mb-2">
              <Calendar className="h-6 w-6 text-indigo-600" />
            </div>
            <h3 className="text-sm font-medium text-gray-500">Tempo Médio (dias)</h3>
            <p className="text-2xl font-bold text-gray-900">{metricas.processos.tempo_medio_conclusao}</p>
          </div>
        </div>
      </div>

      {/* Métricas de Recursos Humanos */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Relatores */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-6">Relatores</h2>
          <div className="space-y-4">
            <div className="flex justify-between">
              <span className="text-gray-600">Total de Relatores:</span>
              <span className="font-semibold">{formatNumber(metricas.relatores.total)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Relatores Ativos:</span>
              <span className="font-semibold">{formatNumber(metricas.relatores.ativos)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Capacidade Disponível:</span>
              <span className="font-semibold">{formatPercentage(metricas.relatores.disponivel_capacidade)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Carga Média:</span>
              <span className="font-semibold">{formatPercentage(metricas.relatores.carga_media)}</span>
            </div>

            <div className="pt-4 border-t border-gray-200">
              <h3 className="text-sm font-medium text-gray-700 mb-3">Distribuição por Especialização</h3>
              <div className="space-y-2">
                {Object.entries(metricas.relatores.distribuicao_especializacoes).map(([especialização, count]) => (
                  <div key={especialização} className="flex justify-between text-sm">
                    <span className="capitalize">{especialização}:</span>
                    <span className="font-medium">{count}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Julgadores */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-6">Julgadores</h2>
          <div className="space-y-4">
            <div className="flex justify-between">
              <span className="text-gray-600">Total de Julgadores:</span>
              <span className="font-semibold">{formatNumber(metricas.julgadores.total)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Ativos no Período:</span>
              <span className="font-semibold">{formatNumber(metricas.julgadores.ativos_ultimo_mes)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Votos no Período:</span>
              <span className="font-semibold">{formatNumber(metricas.julgadores.votos_ultimo_mes)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Tempo Médio p/ Voto:</span>
              <span className="font-semibold">{metricas.julgadores.tempo_medio_voto} min</span>
            </div>
          </div>
        </div>
      </div>

      {/* Performance e Tendências */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-lg font-semibold text-gray-900">Performance e Tendências</h2>
          <div className="flex items-center space-x-4">
            <div className={cn('flex items-center space-x-1', getTendenciaColor(metricas.performance.tendencia_volume))}>
              {getTendenciaIcon(metricas.performance.tendencia_volume)}
              <span className="text-sm font-medium">
                Volume: {metricas.performance.tendencia_volume > 0 ? '+' : ''}{formatPercentage(metricas.performance.tendencia_volume)}
              </span>
            </div>
            <div className={cn('flex items-center space-x-1', getTendenciaColor(-metricas.performance.tendencia_tempo))}>
              {getTendenciaIcon(-metricas.performance.tendencia_tempo)}
              <span className="text-sm font-medium">
                Tempo: {metricas.performance.tendencia_tempo > 0 ? '+' : ''}{formatPercentage(metricas.performance.tendencia_tempo)}
              </span>
            </div>
          </div>
        </div>

        {/* Resolução por Tipo */}
        <div className="space-y-4">
          <h3 className="font-medium text-gray-900">Resolução por Tipo de Infração</h3>
          <div className="space-y-3">
            {metricas.performance.resolucao_por_tipo.map((item) => (
              <div key={item.tipo} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div className="flex-1">
                  <h4 className="font-medium text-gray-900 capitalize">
                    {item.tipo.replace('_', ' ')}
                  </h4>
                  <p className="text-sm text-gray-600">
                    {formatNumber(item.total)} processos • Média: {item.media_dias} dias
                  </p>
                </div>
                <div className="text-right">
                  <span className="text-lg font-bold text-gray-900">
                    {formatNumber(item.total)}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Gráfico de Volume Diário (Mockup) */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-lg font-semibold text-gray-900">Volume de Processos (Últimos 30 dias)</h2>
          <Button variant="outline" size="sm">
            <BarChart3 className="h-4 w-4 mr-2" />
            Ver Detalhes
          </Button>
        </div>
        <div className="h-64 bg-gray-50 rounded-lg flex items-center justify-center">
          <div className="text-center">
            <BarChart3 className="mx-auto h-12 w-12 text-gray-400 mb-4" />
            <p className="text-gray-600">Gráfico de volume diário</p>
            <p className="text-sm text-gray-500">
              {metricas.performance.processos_por_dia.length} pontos de dados disponíveis
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}