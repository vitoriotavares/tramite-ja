# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Permitir acesso do frontend Next.js durante desenvolvimento e produção
    origins(
      'http://localhost:3000',      # Frontend local
      'https://*.vercel.app',       # Vercel deployments
      'https://tramiteja.com.br',   # Domínio de produção
      'https://*.tramiteja.com.br'  # Subdomínios
    )

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      # Permitir cookies para autenticação
      credentials: true,
      # Headers específicos para TrâmiteJá
      expose: ['X-Total-Count', 'X-Page', 'X-Per-Page']
  end

  # Permitir acesso público apenas para endpoints de acompanhamento
  allow do
    origins '*'
    resource '/api/v1/acompanhamento/*',
      headers: :any,
      methods: [:get, :options, :head],
      credentials: false
  end
end
