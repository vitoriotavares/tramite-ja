'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import { ProcessForm } from '@/components/ProcessForm'
import { DocumentUpload } from '@/components/DocumentUpload'
import { ArrowLeft, Check, FileText, Upload, Send } from 'lucide-react'

export default function NovoProcessoPage() {
  const [step, setStep] = useState(1)
  const [processoData, setProcessoData] = useState({
    tipoInfracao: '',
    numeroAuto: '',
    dataInfracao: '',
    localInfracao: '',
    fundamentacao: ''
  })

  const steps = [
    { number: 1, title: 'Dados da Infração', icon: FileText },
    { number: 2, title: 'Upload de Documentos', icon: Upload },
    { number: 3, title: 'Revisão e Envio', icon: Send }
  ]

  const handleStepComplete = (data: any) => {
    setProcessoData({ ...processoData, ...data })
    setStep(step + 1)
  }

  const renderStepContent = () => {
    switch (step) {
      case 1:
        return <ProcessForm onComplete={handleStepComplete} />
      case 2:
        return <DocumentUpload processoId="" onUploadComplete={() => setStep(3)} />
      case 3:
        return <ReviewStep data={processoData} />
      default:
        return null
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex items-center space-x-4">
            <Button
              variant="ghost"
              onClick={() => window.location.href = '/processos'}
              className="p-2"
            >
              <ArrowLeft className="h-5 w-5" />
            </Button>
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Novo Processo</h1>
              <p className="text-gray-600">Crie sua defesa de trânsito</p>
            </div>
          </div>
        </div>
      </header>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Progress Steps */}
        <div className="mb-8">
          <div className="flex items-center justify-between">
            {steps.map((stepInfo, index) => {
              const isActive = step === stepInfo.number
              const isCompleted = step > stepInfo.number
              const Icon = stepInfo.icon

              return (
                <div key={stepInfo.number} className="flex items-center">
                  <div className={`flex items-center space-x-2 ${
                    index !== steps.length - 1 ? 'mr-8' : ''
                  }`}>
                    <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                      isCompleted
                        ? 'bg-green-600 text-white'
                        : isActive
                          ? 'bg-blue-600 text-white'
                          : 'bg-gray-200 text-gray-600'
                    }`}>
                      {isCompleted ? (
                        <Check className="h-5 w-5" />
                      ) : (
                        <Icon className="h-5 w-5" />
                      )}
                    </div>
                    <div className="hidden sm:block">
                      <p className={`font-medium ${
                        isActive ? 'text-blue-600' : isCompleted ? 'text-green-600' : 'text-gray-500'
                      }`}>
                        {stepInfo.title}
                      </p>
                    </div>
                  </div>
                  {index !== steps.length - 1 && (
                    <div className={`hidden md:block w-20 h-1 ${
                      step > stepInfo.number ? 'bg-green-600' : 'bg-gray-200'
                    }`} />
                  )}
                </div>
              )
            })}
          </div>
        </div>

        {/* Step Content */}
        <div className="bg-white rounded-lg shadow-sm">
          {renderStepContent()}
        </div>
      </div>
    </div>
  )
}

function ReviewStep({ data }: { data: any }) {
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleSubmit = async () => {
    setIsSubmitting(true)

    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 2000))

    // Redirect to success page or process list
    window.location.href = '/processos'
  }

  return (
    <div className="p-6">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-2">Revisão Final</h2>
        <p className="text-gray-600">
          Revise os dados antes de enviar seu processo
        </p>
      </div>

      <div className="space-y-6">
        {/* Dados da Infração */}
        <div className="border border-gray-200 rounded-lg p-4">
          <h3 className="font-semibold text-gray-900 mb-3">Dados da Infração</h3>
          <div className="grid md:grid-cols-2 gap-4 text-sm">
            <div>
              <span className="text-gray-500">Tipo de Infração:</span>
              <p className="font-medium">{data.tipoInfracao || 'Não informado'}</p>
            </div>
            <div>
              <span className="text-gray-500">Número do Auto:</span>
              <p className="font-medium">{data.numeroAuto || 'Não informado'}</p>
            </div>
            <div>
              <span className="text-gray-500">Data da Infração:</span>
              <p className="font-medium">{data.dataInfracao || 'Não informado'}</p>
            </div>
            <div>
              <span className="text-gray-500">Local da Infração:</span>
              <p className="font-medium">{data.localInfracao || 'Não informado'}</p>
            </div>
          </div>
          {data.fundamentacao && (
            <div className="mt-4">
              <span className="text-gray-500">Fundamentação:</span>
              <p className="font-medium">{data.fundamentacao}</p>
            </div>
          )}
        </div>

        {/* Documentos */}
        <div className="border border-gray-200 rounded-lg p-4">
          <h3 className="font-semibold text-gray-900 mb-3">Documentos Anexados</h3>
          <p className="text-sm text-gray-600">
            Os documentos foram enviados e serão validados pela equipe técnica.
          </p>
        </div>

        {/* Termos */}
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h3 className="font-semibold text-blue-900 mb-2">Informações Importantes</h3>
          <ul className="text-sm text-blue-800 space-y-1">
            <li>• O processo será analisado em até 30 dias</li>
            <li>• Você receberá notificações sobre atualizações</li>
            <li>• Todos os dados são protegidos conforme a LGPD</li>
            <li>• O código de acompanhamento será gerado após o envio</li>
          </ul>
        </div>

        {/* Actions */}
        <div className="flex justify-between">
          <Button
            variant="outline"
            onClick={() => window.history.back()}
          >
            Voltar
          </Button>
          <Button
            onClick={handleSubmit}
            disabled={isSubmitting}
            className="px-8"
          >
            {isSubmitting ? (
              <>
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                Enviando...
              </>
            ) : (
              <>
                <Send className="h-4 w-4 mr-2" />
                Enviar Processo
              </>
            )}
          </Button>
        </div>
      </div>
    </div>
  )
}