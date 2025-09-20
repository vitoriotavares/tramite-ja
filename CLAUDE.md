# TrâmiteJá Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-09-19

## Active Technologies
- **Backend**: Rails 8 API + PostgreSQL
- **Frontend**: Next.js 14 + Shadcn/ui + TypeScript
- **Storage**: R2 Cloudflare (files) + PostgreSQL (data)
- **Auth**: OAuth Gov.br
- **Payments**: Stripe
- **Real-time**: Socket.io
- **Deploy**: Vercel (frontend) + Railway (backend)
- **Testing**: RSpec + Jest/Vitest + Cypress

## Project Structure
```
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/
```

## Key Requirements
- **Language**: 100% Portuguese BR (constitutional requirement)
- **Performance**: <200ms API, <1s page load, 5-day max process time
- **Testing**: 70% unit, 25% integration, 5% E2E (TDD mandatory)
- **Mobile-first**: Every interface must work perfectly on mobile
- **Accessibility**: WCAG 2.1 AA compliance required

## Core Entities
- **Processo**: Traffic defense case with status workflow
- **Cidadao**: Citizens with Gov.br OAuth auth + platform access credit
- **Relator**: Legal reviewers with specialization and workload balancing
- **Julgador**: Judges for collegial voting with quorum detection
- **Pagamento**: Platform access payments (R$ 85.00) - NOT per-process
- **Documento**: File uploads to R2 with validation
- **Voto**: Individual votes with real-time quorum calculation

## API Patterns
- RESTful design with OpenAPI 3.0 spec
- JWT authentication except public tracking endpoints
- Stripe webhooks for payment confirmation
- WebSocket for real-time voting and notifications
- File uploads to R2 Cloudflare with signed URLs

## Commands
```bash
# Backend (Rails)
bundle install
rails server
bundle exec rspec

# Frontend (Next.js)
npm install
npm run dev
npm run test

# Database
rails db:migrate
rails db:seed
```

## Code Style
- **Rails**: Follow standard Rails conventions, use services for business logic
- **Rails Generators**: ALWAYS use Rails generators first for creating code (models, controllers, migrations, etc.)
- **TypeScript**: Strict mode, proper typing for all API interfaces
- **Portuguese**: All user-facing text, API responses, error messages in pt-BR
- **Testing**: TDD with failing tests first, 100% coverage for critical paths (payment, voting, distribution)

## Rails Generator Priority
**CRITICAL**: Before writing any Rails code manually, ALWAYS check if there's a generator available:
```bash
# Use generators for all Rails components
rails generate model Processo codigo_acompanhamento:string tipo_infracao:integer
rails generate controller Api::V1::Processos
rails generate migration AddRelatorToProcessos relator:references
rails generate service ProcessoDistributionService
rails generate job NotificationMailerJob
rails generate serializer ProcessoSerializer
```

## Recent Changes
- 001-tr-mitej-sistema: Added full digital traffic defense platform with Rails 8 API + Next.js 14

<!-- MANUAL ADDITIONS START -->
<!-- Add any manual customizations here - they will be preserved -->
<!-- MANUAL ADDITIONS END -->