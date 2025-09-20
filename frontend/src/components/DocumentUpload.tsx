'use client'

import { useState, useRef } from 'react'
import { Button } from './ui/button'
import { Label } from './ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select'
import { cn } from '@/lib/utils'
import { Upload, File, X, CheckCircle, AlertTriangle, Clock } from 'lucide-react'

interface DocumentFile {
  id: string
  file: File
  tipo: string
  status: 'uploading' | 'success' | 'error' | 'pending'
  progress: number
  error?: string
  url?: string
}

interface DocumentUploadProps {
  processoId: string
  onUploadComplete?: (documento: any) => void
  onUploadError?: (error: string) => void
  className?: string
}

const TIPOS_DOCUMENTO = [
  {
    value: 'cnh',
    label: 'CNH - Carteira Nacional de Habilitação',
    obrigatorio: true,
    descricao: 'Documento obrigatório para todos os tipos de processo'
  },
  {
    value: 'crlv',
    label: 'CRLV - Certificado de Registro e Licenciamento',
    obrigatorio: false, // Será validado dinamicamente baseado no tipo de infração
    descricao: 'Obrigatório para infrações de velocidade e rodízio'
  },
  {
    value: 'comprovante',
    label: 'Comprovante/Documento de Apoio',
    obrigatorio: false,
    descricao: 'Documentos adicionais que comprovem sua defesa'
  },
  {
    value: 'outros',
    label: 'Outros Documentos',
    obrigatorio: false,
    descricao: 'Outros documentos relevantes ao processo'
  }
]

const MAX_FILE_SIZE = 10 * 1024 * 1024 // 10MB
const ALLOWED_TYPES = ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png']
const ALLOWED_EXTENSIONS = ['.pdf', '.jpg', '.jpeg', '.png']

export function DocumentUpload({
  processoId,
  onUploadComplete,
  onUploadError,
  className
}: DocumentUploadProps) {
  const [documents, setDocuments] = useState<DocumentFile[]>([])
  const [selectedType, setSelectedType] = useState<string>('')
  const [dragActive, setDragActive] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const validateFile = (file: File): string | null => {
    // Validar tamanho
    if (file.size > MAX_FILE_SIZE) {
      return `Arquivo muito grande. Máximo permitido: 10MB`
    }

    // Validar tipo
    if (!ALLOWED_TYPES.includes(file.type)) {
      return `Tipo de arquivo não permitido. Use: PDF, JPG, JPEG ou PNG`
    }

    // Validar extensão
    const extension = file.name.toLowerCase().substring(file.name.lastIndexOf('.'))
    if (!ALLOWED_EXTENSIONS.includes(extension)) {
      return `Extensão não permitida. Use: ${ALLOWED_EXTENSIONS.join(', ')}`
    }

    return null
  }

  const generateId = () => Math.random().toString(36).substr(2, 9)

  const handleFiles = (files: FileList | null, tipo?: string) => {
    if (!files || files.length === 0) return

    const fileType = tipo || selectedType
    if (!fileType) {
      onUploadError?.('Selecione o tipo do documento antes de fazer upload')
      return
    }

    Array.from(files).forEach((file) => {
      const error = validateFile(file)

      const documentFile: DocumentFile = {
        id: generateId(),
        file,
        tipo: fileType,
        status: error ? 'error' : 'pending',
        progress: 0,
        error
      }

      setDocuments(prev => [...prev, documentFile])

      if (!error) {
        uploadFile(documentFile)
      }
    })

    // Limpar seleção
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  const uploadFile = async (documentFile: DocumentFile) => {
    setDocuments(prev =>
      prev.map(doc =>
        doc.id === documentFile.id
          ? { ...doc, status: 'uploading', progress: 0 }
          : doc
      )
    )

    try {
      // Simular progresso de upload
      const progressInterval = setInterval(() => {
        setDocuments(prev =>
          prev.map(doc => {
            if (doc.id === documentFile.id && doc.progress < 90) {
              return { ...doc, progress: doc.progress + 10 }
            }
            return doc
          })
        )
      }, 200)

      // Preparar FormData
      const formData = new FormData()
      formData.append('documento[tipo]', documentFile.tipo)
      formData.append('documento[arquivo]', documentFile.file)

      // Simular chamada à API (substituir pela implementação real)
      const response = await fetch(`/api/v1/processos/${processoId}/documentos`, {
        method: 'POST',
        body: formData,
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}` // Implementar autenticação
        }
      })

      clearInterval(progressInterval)

      if (!response.ok) {
        throw new Error(`Erro no upload: ${response.statusText}`)
      }

      const resultado = await response.json()

      setDocuments(prev =>
        prev.map(doc =>
          doc.id === documentFile.id
            ? {
                ...doc,
                status: 'success',
                progress: 100,
                url: resultado.url
              }
            : doc
        )
      )

      onUploadComplete?.(resultado)

    } catch (error) {
      setDocuments(prev =>
        prev.map(doc =>
          doc.id === documentFile.id
            ? {
                ...doc,
                status: 'error',
                error: error instanceof Error ? error.message : 'Erro no upload'
              }
            : doc
        )
      )

      onUploadError?.(error instanceof Error ? error.message : 'Erro no upload')
    }
  }

  const removeDocument = (id: string) => {
    setDocuments(prev => prev.filter(doc => doc.id !== id))
  }

  const retryUpload = (id: string) => {
    const document = documents.find(doc => doc.id === id)
    if (document) {
      uploadFile(document)
    }
  }

  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()

    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true)
    } else if (e.type === 'dragleave') {
      setDragActive(false)
    }
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setDragActive(false)

    if (e.dataTransfer.files) {
      handleFiles(e.dataTransfer.files)
    }
  }

  const openFileDialog = () => {
    if (!selectedType) {
      onUploadError?.('Selecione o tipo do documento primeiro')
      return
    }
    fileInputRef.current?.click()
  }

  const getStatusIcon = (status: DocumentFile['status']) => {
    switch (status) {
      case 'success':
        return <CheckCircle className="h-5 w-5 text-green-500" />
      case 'error':
        return <AlertTriangle className="h-5 w-5 text-red-500" />
      case 'uploading':
        return <Clock className="h-5 w-5 text-blue-500 animate-spin" />
      default:
        return <File className="h-5 w-5 text-gray-500" />
    }
  }

  const getStatusText = (doc: DocumentFile) => {
    switch (doc.status) {
      case 'success':
        return 'Upload concluído'
      case 'error':
        return doc.error || 'Erro no upload'
      case 'uploading':
        return `Enviando... ${doc.progress}%`
      default:
        return 'Aguardando envio'
    }
  }

  return (
    <div className={cn('w-full max-w-4xl mx-auto', className)}>
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="mb-6">
          <h2 className="text-xl font-bold text-gray-900 mb-2">
            Upload de Documentos
          </h2>
          <p className="text-gray-600">
            Envie os documentos necessários para seu processo.
            Formatos aceitos: PDF, JPG, JPEG, PNG (até 10MB cada).
          </p>
        </div>

        {/* Seletor de Tipo */}
        <div className="mb-6">
          <Label htmlFor="tipo_documento" className="text-sm font-medium text-gray-700 mb-2 block">
            Tipo de Documento
          </Label>
          <Select value={selectedType} onValueChange={setSelectedType}>
            <SelectTrigger className="w-full max-w-md">
              <SelectValue placeholder="Selecione o tipo do documento" />
            </SelectTrigger>
            <SelectContent>
              {TIPOS_DOCUMENTO.map((tipo) => (
                <SelectItem key={tipo.value} value={tipo.value}>
                  <div className="flex items-center space-x-2">
                    <span>{tipo.label}</span>
                    {tipo.obrigatorio && (
                      <span className="text-xs bg-red-100 text-red-800 px-1.5 py-0.5 rounded">
                        Obrigatório
                      </span>
                    )}
                  </div>
                </SelectItem>
              ))}
            </SelectContent>
          </Select>

          {selectedType && (
            <p className="text-sm text-gray-600 mt-1">
              {TIPOS_DOCUMENTO.find(t => t.value === selectedType)?.descricao}
            </p>
          )}
        </div>

        {/* Área de Upload */}
        <div
          className={cn(
            'border-2 border-dashed rounded-lg p-8 text-center transition-colors',
            dragActive
              ? 'border-blue-500 bg-blue-50'
              : 'border-gray-300 hover:border-gray-400',
            !selectedType && 'opacity-50 cursor-not-allowed'
          )}
          onDragEnter={handleDrag}
          onDragLeave={handleDrag}
          onDragOver={handleDrag}
          onDrop={handleDrop}
        >
          <Upload className="mx-auto h-12 w-12 text-gray-400 mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">
            Arraste arquivos aqui ou clique para selecionar
          </h3>
          <p className="text-sm text-gray-600 mb-4">
            PDF, JPG, JPEG, PNG até 10MB
          </p>
          <Button
            type="button"
            variant="outline"
            onClick={openFileDialog}
            disabled={!selectedType}
            className="mx-auto"
          >
            Selecionar Arquivos
          </Button>
        </div>

        {/* Input File Oculto */}
        <input
          ref={fileInputRef}
          type="file"
          multiple
          accept=".pdf,.jpg,.jpeg,.png"
          onChange={(e) => handleFiles(e.target.files)}
          className="hidden"
        />

        {/* Lista de Documentos */}
        {documents.length > 0 && (
          <div className="mt-8">
            <h3 className="text-lg font-medium text-gray-900 mb-4">
              Documentos ({documents.length})
            </h3>
            <div className="space-y-3">
              {documents.map((doc) => (
                <div
                  key={doc.id}
                  className="flex items-center justify-between p-4 border border-gray-200 rounded-lg"
                >
                  <div className="flex items-center space-x-3 flex-1">
                    {getStatusIcon(doc.status)}
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 truncate">
                        {doc.file.name}
                      </p>
                      <div className="flex items-center space-x-4 text-xs text-gray-500">
                        <span>{TIPOS_DOCUMENTO.find(t => t.value === doc.tipo)?.label}</span>
                        <span>{(doc.file.size / 1024 / 1024).toFixed(1)} MB</span>
                        <span className={cn(
                          doc.status === 'success' && 'text-green-600',
                          doc.status === 'error' && 'text-red-600',
                          doc.status === 'uploading' && 'text-blue-600'
                        )}>
                          {getStatusText(doc)}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center space-x-2">
                    {doc.status === 'error' && (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => retryUpload(doc.id)}
                      >
                        Tentar Novamente
                      </Button>
                    )}
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => removeDocument(doc.id)}
                      className="text-red-600 hover:text-red-700"
                    >
                      <X className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Documentos Obrigatórios */}
        <div className="mt-8 bg-amber-50 border border-amber-200 rounded-lg p-4">
          <h3 className="text-sm font-semibold text-amber-900 mb-2">
            📋 Documentos Obrigatórios
          </h3>
          <ul className="text-sm text-amber-800 space-y-1">
            <li>• <strong>CNH:</strong> Obrigatória para todos os tipos de processo</li>
            <li>• <strong>CRLV:</strong> Obrigatório para infrações de velocidade e rodízio</li>
            <li>• <strong>Comprovantes:</strong> Documentos que fundamentem sua defesa (opcional)</li>
          </ul>
        </div>
      </div>
    </div>
  )
}