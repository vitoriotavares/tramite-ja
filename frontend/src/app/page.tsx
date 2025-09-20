'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Search, FileText, Scale, Users, BarChart3 } from 'lucide-react'

export default function HomePage() {
  const [codigoAcompanhamento, setCodigoAcompanhamento] = useState('')

  const handleConsultarProcesso = () => {
    if (codigoAcompanhamento.trim()) {
      window.location.href = `/processo/${codigoAcompanhamento}`
    }
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="bg-card shadow-sm border-b border-border">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-3">
              <Scale className="h-8 w-8 text-primary" />
              <h1 className="text-2xl font-bold text-foreground">TrâmiteJá</h1>
            </div>
            <nav className="flex space-x-6">
              <a href="/processos" className="text-muted-foreground hover:text-primary font-medium">
                Meus Processos
              </a>
              <a href="/novo-processo" className="text-muted-foreground hover:text-primary font-medium">
                Novo Processo
              </a>
              <Button size="sm">
                Entrar com Gov.br
              </Button>
            </nav>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center mb-16">
          <h1 className="text-4xl md:text-6xl font-bold text-foreground mb-6">
            Defesa de Trânsito
            <span className="block text-primary">100% Digital</span>
          </h1>
          <p className="text-xl text-muted-foreground max-w-3xl mx-auto mb-8">
            Plataforma oficial para recursos de multas de trânsito.
            Processo transparente, seguro e com acompanhamento em tempo real.
          </p>

          {/* Consulta de Processo */}
          <div className="max-w-md mx-auto mb-12">
            <div className="flex space-x-3">
              <Input
                placeholder="Digite o código de acompanhamento"
                value={codigoAcompanhamento}
                onChange={(e) => setCodigoAcompanhamento(e.target.value)}
                className="flex-1"
                onKeyPress={(e) => e.key === 'Enter' && handleConsultarProcesso()}
              />
              <Button onClick={handleConsultarProcesso} className="px-6">
                <Search className="h-4 w-4 mr-2" />
                Consultar
              </Button>
            </div>
            <p className="text-sm text-muted-foreground mt-2">
              Ex: ABCD-1234-EFGH
            </p>
          </div>
        </div>

        {/* Features */}
        <div className="grid md:grid-cols-3 gap-8 mb-16">
          <div className="bg-card rounded-lg p-6 shadow-md hover:shadow-lg transition-shadow border border-border">
            <FileText className="h-10 w-10 text-primary mb-4" />
            <h3 className="text-xl font-semibold mb-3 text-card-foreground">Processo Digital</h3>
            <p className="text-muted-foreground">
              Upload de documentos, acompanhamento online e notificações automáticas.
            </p>
          </div>

          <div className="bg-card rounded-lg p-6 shadow-md hover:shadow-lg transition-shadow border border-border">
            <Users className="h-10 w-10 text-primary mb-4" />
            <h3 className="text-xl font-semibold mb-3 text-card-foreground">Análise Especializada</h3>
            <p className="text-muted-foreground">
              Relatores especialistas analisam seu caso com foco na legislação específica.
            </p>
          </div>

          <div className="bg-card rounded-lg p-6 shadow-md hover:shadow-lg transition-shadow border border-border">
            <BarChart3 className="h-10 w-10 text-primary mb-4" />
            <h3 className="text-xl font-semibold mb-3 text-card-foreground">Transparência Total</h3>
            <p className="text-muted-foreground">
              Acompanhe cada etapa do processo e veja as decisões em tempo real.
            </p>
          </div>
        </div>

        {/* CTA Section */}
        <div className="bg-card rounded-lg p-8 shadow-md text-center border border-border">
          <h2 className="text-3xl font-bold text-card-foreground mb-4">
            Pronto para começar?
          </h2>
          <p className="text-muted-foreground mb-6">
            Crie sua defesa em poucos minutos e acompanhe todo o processo online.
          </p>
          <Button size="lg" className="px-8">
            Iniciar Novo Processo
          </Button>
        </div>
      </main>

      {/* Footer */}
      <footer className="bg-sidebar text-sidebar-foreground py-8 mt-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <p className="text-sidebar-foreground/80">
            © 2025 TrâmiteJá - Plataforma Digital de Defesa de Trânsito
          </p>
          <p className="text-sidebar-foreground/60 text-sm mt-2">
            Desenvolvido para transparência e eficiência na justiça de trânsito
          </p>
        </div>
      </footer>
    </div>
  )
}