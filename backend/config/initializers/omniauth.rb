# OmniAuth configuration for Gov.br integration
# This configures OAuth authentication with the Brazilian government identity provider

# TODO: Implement Gov.br OAuth provider when available
# Rails.application.config.middleware.use OmniAuth::Builder do
#   # Gov.br OAuth provider configuration
#   # Use credentials to store sensitive data: rails credentials:edit
#   provider :govbr,
#     Rails.application.credentials.dig(:govbr, :client_id),
#     Rails.application.credentials.dig(:govbr, :client_secret),
#     {
#       scope: 'openid profile email phone cpf',
#       client_options: {
#         site: Rails.application.credentials.dig(:govbr, :site) || 'https://sso.staging.acesso.gov.br',
#         authorize_url: '/authorize',
#         token_url: '/token',
#         userinfo_url: '/userinfo'
#       },
#       # TrâmiteJá specific configuration
#       name: 'govbr',
#       # Redirect to our authentication callback
#       redirect_uri: Rails.application.credentials.dig(:govbr, :redirect_uri)
#     }
# end

# Configure OmniAuth settings
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true

# Security: Disable test mode in production
OmniAuth.config.test_mode = Rails.env.test?

# CSRF protection is handled by omniauth-rails_csrf_protection gem

# Logging for debugging
OmniAuth.config.logger = Rails.logger

# Error handling
OmniAuth.config.on_failure = proc { |env|
  Rails.logger.error "OmniAuth failure: #{env['omniauth.error']}"
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
}