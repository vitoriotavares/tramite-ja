'use client'

import { useState } from 'react'
import { ManagementDashboard } from '@/components/ManagementDashboard'
import { Button } from '@/components/ui/button'
import { BarChart3, Users, FileText, Settings, Download, AlertTriangle } from 'lucide-react'

export default function AdminPage() {
  const [activeTab, setActiveTab] = useState('dashboard')

  const estatisticas = {
    processos_total: 847,
    processos_mes: 156,
    processos_pendentes: 23,
    processos_decididos: 824,
    taxa_deferimento: 62.3,
    tempo_medio: 18.5,
    relatores_ativos: 12,
    julgadores_ativos: 25,
    capacidade_sistema: 85.6
  }

  const alertas = [
    {
      id: 1,
      tipo: 'warning',
      titulo: 'Relator com sobrecarga',
      descricao: 'Dr. João Silva está com 18/15 processos atribuídos',
      acao: 'Redistribuir processos'
    },
    {
      id: 2,
      tipo: 'error',
      titulo: 'Prazo vencendo',
      descricao: '3 processos vencem o prazo nas próximas 24h',
      acao: 'Verificar urgentes'
    },
    {
      id: 3,
      tipo: 'info',
      titulo: 'Backup concluído',
      descricao: 'Backup diário realizado com sucesso às 02:00',
      acao: 'Verificar logs'
    }
  ]

  const tabs = [
    { id: 'dashboard', label: 'Dashboard', icon: BarChart3 },
    { id: 'usuarios', label: 'Usuários', icon: Users },
    { id: 'processos', label: 'Processos', icon: FileText },
    { id: 'configuracoes', label: 'Configurações', icon: Settings }
  ]

  return (
    <div className="w-full h-full">
      {/* Header */}
      <div className="mb-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">
              Administração TrâmiteJá
            </h1>
            <p className="text-gray-600">
              Painel de controle e gestão da plataforma
            </p>
          </div>
          <div className="mt-4 sm:mt-0 flex space-x-3">
            <Button variant="outline" size="sm">
              <Download className="h-4 w-4 mr-2" />
              Relatórios
            </Button>
            <Button size="sm">
              <Settings className="h-4 w-4 mr-2" />
              Configurações
            </Button>
          </div>
        </div>
      </div>

      <div className="space-y-6">
        {/* Alertas */}
        <div className="mb-8">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Alertas do Sistema</h2>
          <div className="space-y-3">
            {alertas.map((alerta) => (
              <div key={alerta.id} className={`p-4 rounded-lg border ${
                alerta.tipo === 'error' ? 'bg-red-50 border-red-200' :
                alerta.tipo === 'warning' ? 'bg-yellow-50 border-yellow-200' :
                'bg-blue-50 border-blue-200'
              }`}>
                <div className="flex items-center justify-between">
                  <div className="flex items-start">
                    <AlertTriangle className={`h-5 w-5 mt-0.5 mr-3 ${
                      alerta.tipo === 'error' ? 'text-red-600' :
                      alerta.tipo === 'warning' ? 'text-yellow-600' :
                      'text-blue-600'
                    }`} />
                    <div>
                      <h3 className={`font-medium ${
                        alerta.tipo === 'error' ? 'text-red-900' :
                        alerta.tipo === 'warning' ? 'text-yellow-900' :
                        'text-blue-900'
                      }`}>
                        {alerta.titulo}
                      </h3>
                      <p className={`text-sm ${
                        alerta.tipo === 'error' ? 'text-red-700' :
                        alerta.tipo === 'warning' ? 'text-yellow-700' :
                        'text-blue-700'
                      }`}>
                        {alerta.descricao}
                      </p>
                    </div>
                  </div>
                  <Button variant="ghost" size="sm" className={
                    alerta.tipo === 'error' ? 'text-red-700' :
                    alerta.tipo === 'warning' ? 'text-yellow-700' :
                    'text-blue-700'
                  }>
                    {alerta.acao}
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Estatísticas Principais */}
        <div className="mb-8">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Estatísticas Gerais</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="bg-white rounded-lg shadow p-6">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <FileText className="h-8 w-8 text-blue-600" />
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-500">Total de Processos</p>
                  <p className="text-2xl font-bold text-gray-900">{estatisticas.processos_total}</p>
                  <p className="text-sm text-green-600">+{estatisticas.processos_mes} este mês</p>
                </div>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow p-6">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <BarChart3 className="h-8 w-8 text-green-600" />
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-500">Taxa de Deferimento</p>
                  <p className="text-2xl font-bold text-gray-900">{estatisticas.taxa_deferimento}%</p>
                  <p className="text-sm text-gray-600">Últimos 30 dias</p>
                </div>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow p-6">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <Users className="h-8 w-8 text-purple-600" />
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-500">Operadores Ativos</p>
                  <p className="text-2xl font-bold text-gray-900">
                    {estatisticas.relatores_ativos + estatisticas.julgadores_ativos}
                  </p>
                  <p className="text-sm text-gray-600">
                    {estatisticas.relatores_ativos}R + {estatisticas.julgadores_ativos}J
                  </p>
                </div>
              </div>
            </div>

            <div className="bg-white rounded-lg shadow p-6">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <AlertTriangle className="h-8 w-8 text-orange-600" />
                </div>
                <div className="ml-4">
                  <p className="text-sm font-medium text-gray-500">Tempo Médio</p>
                  <p className="text-2xl font-bold text-gray-900">{estatisticas.tempo_medio} dias</p>
                  <p className="text-sm text-gray-600">Por processo</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Tabs Navigation */}
        <div className="mb-6">
          <div className="border-b border-gray-200">
            <nav className="-mb-px flex space-x-8">
              {tabs.map((tab) => {
                const Icon = tab.icon
                return (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={`py-2 px-1 border-b-2 font-medium text-sm flex items-center space-x-2 ${
                      activeTab === tab.id
                        ? 'border-blue-500 text-blue-600'
                        : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                    }`}
                  >
                    <Icon className="h-4 w-4" />
                    <span>{tab.label}</span>
                  </button>
                )
              })}
            </nav>
          </div>
        </div>

        {/* Tab Content */}
        <div className="bg-white rounded-lg shadow">
          {activeTab === 'dashboard' && (
            <div className="p-6">
              <ManagementDashboard />
            </div>
          )}

          {activeTab === 'usuarios' && (
            <div className="p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Gestão de Usuários</h3>
              <div className="grid md:grid-cols-2 gap-6">
                <div className="border border-gray-200 rounded-lg p-4">
                  <h4 className="font-medium text-gray-900 mb-3">Relatores</h4>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span>Total ativo:</span>
                      <span className="font-medium">{estatisticas.relatores_ativos}</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Capacidade média:</span>
                      <span className="font-medium">12.5 processos</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Utilização:</span>
                      <span className="font-medium text-yellow-600">78%</span>
                    </div>
                  </div>
                </div>

                <div className="border border-gray-200 rounded-lg p-4">
                  <h4 className="font-medium text-gray-900 mb-3">Julgadores</h4>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span>Total ativo:</span>
                      <span className="font-medium">{estatisticas.julgadores_ativos}</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Votos pendentes:</span>
                      <span className="font-medium">47</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Tempo médio:</span>
                      <span className="font-medium text-green-600">2.3 dias</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'processos' && (
            <div className="p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Gestão de Processos</h3>
              <div className="grid md:grid-cols-3 gap-6">
                <div className="text-center">
                  <p className="text-3xl font-bold text-blue-600">{estatisticas.processos_pendentes}</p>
                  <p className="text-sm text-gray-600">Pendentes</p>
                </div>
                <div className="text-center">
                  <p className="text-3xl font-bold text-yellow-600">156</p>
                  <p className="text-sm text-gray-600">Em análise</p>
                </div>
                <div className="text-center">
                  <p className="text-3xl font-bold text-green-600">{estatisticas.processos_decididos}</p>
                  <p className="text-sm text-gray-600">Decididos</p>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'configuracoes' && (
            <div className="p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Configurações do Sistema</h3>
              <div className="space-y-4">
                <div className="flex items-center justify-between py-3 border-b border-gray-200">
                  <div>
                    <p className="font-medium">Capacidade do Sistema</p>
                    <p className="text-sm text-gray-600">Utilização atual: {estatisticas.capacidade_sistema}%</p>
                  </div>
                  <Button variant="outline" size="sm">Ajustar</Button>
                </div>
                <div className="flex items-center justify-between py-3 border-b border-gray-200">
                  <div>
                    <p className="font-medium">Backup Automático</p>
                    <p className="text-sm text-gray-600">Último backup: hoje às 02:00</p>
                  </div>
                  <Button variant="outline" size="sm">Configurar</Button>
                </div>
                <div className="flex items-center justify-between py-3">
                  <div>
                    <p className="font-medium">Notificações</p>
                    <p className="text-sm text-gray-600">E-mail e SMS habilitados</p>
                  </div>
                  <Button variant="outline" size="sm">Gerenciar</Button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}