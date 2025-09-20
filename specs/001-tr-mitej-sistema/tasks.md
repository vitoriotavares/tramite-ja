# Tasks: TrâmiteJá - Sistema Digital de Defesa Prévia

**Input**: Design documents from `/specs/001-tr-mitej-sistema/`
**Prerequisites**: plan.md, research.md, data-model.md, contracts/, quickstart.md

## Path Conventions
- **Backend**: `backend/` directory at repository root
- **Frontend**: `frontend/` directory at repository root
- **Tests**: Within respective backend/spec/ and frontend/tests/ directories

## Phase 3.1: Setup
- [x] T001 Create Rails 8 API project structure in backend/ directory
- [x] T002 Initialize Next.js 14 project structure in frontend/ directory
- [x] T003 [P] Configure PostgreSQL database connection in backend/config/database.yml
- [x] T004 [P] Setup R2 Cloudflare storage configuration in backend/config/storage.yml
- [x] T005 [P] Setup OAuth Gov.br configuration in backend/config/initializers/omniauth.rb
- [x] T006 [P] Configure Socket.io real-time connection in both backend/ and frontend/
- [x] T007 [P] Setup linting tools: Rubocop (backend), ESLint/Prettier (frontend)
- [x] T008 [P] Configure CORS settings in backend/config/initializers/cors.rb

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

### Contract Tests
- [x] T009 [P] Contract test POST /api/v1/processos in backend/spec/requests/api/v1/processos_spec.rb
- [x] T010 [P] Contract test GET /api/v1/processos in backend/spec/requests/api/v1/processos_spec.rb
- [x] T011 [P] Contract test GET /api/v1/processos/{id} in backend/spec/requests/api/v1/processos_spec.rb
- [x] T012 [P] Contract test PATCH /api/v1/processos/{id} in backend/spec/requests/api/v1/processos_spec.rb
- [x] T013 [P] Contract test GET /api/v1/acompanhamento/{codigo} in backend/spec/requests/api/v1/acompanhamento_spec.rb
- [x] T014 [P] Contract test POST /api/v1/processos/{id}/documentos in backend/spec/requests/api/v1/documentos_spec.rb
- [x] T015 [P] Contract test GET /api/v1/processos/{id}/documentos in backend/spec/requests/api/v1/documentos_spec.rb
- [x] T016 [P] Contract test POST /api/v1/processos/{id}/votos in backend/spec/requests/api/v1/votos_spec.rb
- [x] T017 [P] Contract test GET /api/v1/processos/{id}/votos in backend/spec/requests/api/v1/votos_spec.rb
- [x] T018 [P] Contract test GET /api/v1/dashboard/metricas in backend/spec/requests/api/v1/dashboard_spec.rb
- [x] T019 [P] Contract test GET /api/v1/relatores in backend/spec/requests/api/v1/relatores_spec.rb
- [x] T020 [P] Contract test GET /api/v1/relatores/{id}/dashboard in backend/spec/requests/api/v1/relatores_spec.rb

### Integration Tests (Based on Quickstart Scenarios)
- [x] T021 [P] Integration test: Complete citizen defense flow (free access) in backend/spec/features/complete_defense_flow_spec.rb
- [x] T022 [P] Integration test: Triage rejection for incomplete docs in backend/spec/features/triage_rejection_spec.rb
- [x] T023 [P] Integration test: Collegial voting with disagreement in backend/spec/features/voting_disagreement_spec.rb
- [x] T024 [P] Integration test: Real-time notifications via Socket.io in backend/spec/features/realtime_notifications_spec.rb
- [x] T025 [P] Integration test: Performance load testing (100 processes) in backend/spec/features/performance_load_spec.rb

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### Models (Using Rails Generators)
- [x] T026 [P] Generate Cidadao model with rails generate model in backend/app/models/cidadao.rb
- [x] T027 [P] Generate Relator model with rails generate model in backend/app/models/relator.rb
- [x] T028 [P] Generate Julgador model with rails generate model in backend/app/models/julgador.rb
- [x] T029 [P] Generate Processo model with rails generate model in backend/app/models/processo.rb
- [x] T030 [P] Generate Voto model with rails generate model in backend/app/models/voto.rb
- [x] T031 [P] Generate Documento model with rails generate model in backend/app/models/documento.rb
- [x] T032 [P] Generate Notificacao model with rails generate model in backend/app/models/notificacao.rb

### Services (Business Logic)
- [x] T033 [P] Create ProcessoDistributionService for intelligent assignment in backend/app/services/processo_distribution_service.rb
- [x] T034 [P] Create TriagemService for automated document validation in backend/app/services/triagem_service.rb
- [x] T035 [P] Create VotacaoService for quorum detection and decisions in backend/app/services/votacao_service.rb
- [x] T036 [P] Create NotificationService for email notifications in backend/app/services/notification_service.rb
- [x] T037 [P] Create DocumentUploadService for R2 Cloudflare integration in backend/app/services/document_upload_service.rb

### API Controllers
- [x] T038 Generate ProcessosController with rails generate controller in backend/app/controllers/api/v1/processos_controller.rb
- [x] T039 Generate AcompanhamentoController in backend/app/controllers/api/v1/acompanhamento_controller.rb
- [x] T040 Generate DocumentosController in backend/app/controllers/api/v1/documentos_controller.rb
- [x] T041 Generate VotosController in backend/app/controllers/api/v1/votos_controller.rb
- [x] T042 Generate DashboardController in backend/app/controllers/api/v1/dashboard_controller.rb
- [x] T043 Generate RelatoresController in backend/app/controllers/api/v1/relatores_controller.rb

### Frontend Components (Next.js + Shadcn/ui)
- [ ] T044 [P] Create ProcessForm component for citizen process submission in frontend/src/components/ProcessForm.tsx
- [ ] T045 [P] Create DocumentUpload component for file uploads in frontend/src/components/DocumentUpload.tsx
- [ ] T046 [P] Create ProcessTimeline component for public tracking in frontend/src/components/ProcessTimeline.tsx
- [ ] T047 [P] Create RelatorDashboard component for reviewer interface in frontend/src/components/RelatorDashboard.tsx
- [ ] T048 [P] Create VotingInterface component for judges in frontend/src/components/VotingInterface.tsx
- [ ] T049 [P] Create ManagementDashboard component for metrics in frontend/src/components/ManagementDashboard.tsx

### Frontend Pages
- [ ] T050 Create citizen portal page in frontend/src/pages/cidadao/index.tsx
- [ ] T051 Create public tracking page in frontend/src/pages/acompanhamento/[codigo].tsx
- [ ] T052 Create relator dashboard page in frontend/src/pages/relator/dashboard.tsx
- [ ] T053 Create julgador voting page in frontend/src/pages/julgador/votacao.tsx
- [ ] T054 Create admin dashboard page in frontend/src/pages/admin/dashboard.tsx

## Phase 3.4: Integration

### Authentication & Authorization
- [ ] T055 Configure OAuth Gov.br authentication middleware in backend/app/controllers/concerns/authenticatable.rb
- [ ] T056 Create JWT token management in backend/app/services/jwt_service.rb
- [ ] T057 Setup role-based authorization (Cidadao, Relator, Julgador) in backend/app/controllers/concerns/authorizable.rb

### Real-time Features
- [ ] T058 Implement Socket.io server for real-time updates in backend/app/channels/process_channel.rb
- [ ] T059 Create real-time voting notifications in backend/app/jobs/voting_notification_job.rb
- [ ] T060 Setup WebSocket client connections in frontend/src/hooks/useSocket.ts

### External Integrations
- [ ] T061 Setup R2 Cloudflare file upload integration in backend/config/initializers/aws.rb
- [ ] T062 Configure email notifications with background jobs in backend/app/jobs/notification_mailer_job.rb

### Database & Migrations
- [ ] T063 Create database migrations for all models using rails generate migration
- [ ] T064 Setup database indexes for performance optimization
- [ ] T065 Create database seeds for test users and data in backend/db/seeds.rb

## Phase 3.5: Polish

### Unit Tests
- [ ] T066 [P] Unit tests for ProcessoDistributionService in backend/spec/services/processo_distribution_service_spec.rb
- [ ] T067 [P] Unit tests for TriagemService in backend/spec/services/triagem_service_spec.rb
- [ ] T068 [P] Unit tests for VotacaoService in backend/spec/services/votacao_service_spec.rb
- [ ] T069 [P] Unit tests for all models validations in backend/spec/models/
- [ ] T070 [P] Frontend component tests with Jest in frontend/tests/components/
- [ ] T071 [P] Frontend hook tests in frontend/tests/hooks/

### Performance & Monitoring
- [ ] T072 Setup performance monitoring with response time tracking
- [ ] T073 Configure database query optimization and N+1 detection
- [ ] T074 Implement caching strategy for frequently accessed data
- [ ] T075 Setup monitoring dashboards for system metrics

### E2E Testing
- [ ] T076 [P] Cypress E2E test for complete citizen flow in frontend/cypress/integration/citizen_flow.cy.ts
- [ ] T077 [P] Cypress E2E test for relator workflow in frontend/cypress/integration/relator_workflow.cy.ts
- [ ] T078 [P] Cypress E2E test for voting process in frontend/cypress/integration/voting_process.cy.ts

### Documentation & Deployment
- [ ] T079 [P] Create API documentation with OpenAPI/Swagger UI
- [ ] T080 [P] Setup Docker configuration for local development
- [ ] T081 [P] Configure Vercel deployment for frontend
- [ ] T082 [P] Configure Railway deployment for backend
- [ ] T083 [P] Create deployment scripts and CI/CD pipeline

## Dependencies

### Critical Path Dependencies
- Setup (T001-T008) must complete before all other phases
- Contract tests (T009-T020) must complete and FAIL before models (T026-T032)
- Models (T026-T032) must complete before services (T033-T037)
- Services (T033-T037) must complete before controllers (T038-T043)
- Backend API must be functional before frontend components (T044-T049)

### Specific Dependencies
- T029 (Processo model) blocks T033 (ProcessoDistributionService), T034 (TriagemService)
- T030 (Voto model) blocks T035 (VotacaoService)
- T033-T037 (All services) block T038-T043 (Controllers)
- T063 (Migrations) must run after all models (T026-T032)
- T055-T057 (Auth) blocks protected endpoints
- T058-T060 (Real-time) blocks voting notifications

## Parallel Execution Examples

### Phase 3.2 - All Contract Tests Together
```
Task: "Contract test POST /api/v1/processos in backend/spec/requests/api/v1/processos_spec.rb"
Task: "Contract test GET /api/v1/processos in backend/spec/requests/api/v1/processos_spec.rb"
Task: "Contract test GET /api/v1/acompanhamento/{codigo} in backend/spec/requests/api/v1/acompanhamento_spec.rb"
Task: "Integration test: Complete citizen defense flow (free access) in backend/spec/features/complete_defense_flow_spec.rb"
```

### Phase 3.3 - All Models Together
```
Task: "Generate Cidadao model with rails generate model in backend/app/models/cidadao.rb"
Task: "Generate Relator model with rails generate model in backend/app/models/relator.rb"
Task: "Generate Julgador model with rails generate model in backend/app/models/julgador.rb"
Task: "Generate Processo model with rails generate model in backend/app/models/processo.rb"
Task: "Generate Voto model with rails generate model in backend/app/models/voto.rb"
```

### Phase 3.3 - All Services Together (after models)
```
Task: "Create ProcessoDistributionService for intelligent assignment in backend/app/services/processo_distribution_service.rb"
Task: "Create TriagemService for automated document validation in backend/app/services/triagem_service.rb"
Task: "Create VotacaoService for quorum detection and decisions in backend/app/services/votacao_service.rb"
Task: "Create NotificationService for email notifications in backend/app/services/notification_service.rb"
```

### Phase 3.3 - All Frontend Components Together
```
Task: "Create ProcessForm component for citizen process submission in frontend/src/components/ProcessForm.tsx"
Task: "Create DocumentUpload component for file uploads in frontend/src/components/DocumentUpload.tsx"
Task: "Create ProcessTimeline component for public tracking in frontend/src/components/ProcessTimeline.tsx"
Task: "Create RelatorDashboard component for reviewer interface in frontend/src/components/RelatorDashboard.tsx"
```

## Validation Checklist
*GATE: Checked before implementation complete*

- [x] All API endpoints have corresponding contract tests
- [x] All entities have model creation tasks
- [x] All tests come before implementation (TDD enforced)
- [x] Parallel tasks are truly independent (different files)
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task
- [x] Critical paths identified: Voting, Distribution (100% test coverage)
- [x] Performance requirements addressed (<200ms API, <1s page load)
- [x] Portuguese BR requirement integrated throughout
- [x] Mobile-first and accessibility considerations included
- [x] Free access model implemented (no payment barriers)

## Notes
- **[P] tasks**: Can run in parallel (different files, no dependencies)
- **Rails generators**: Always use Rails generators first before manual coding
- **TDD enforcement**: All tests must fail before implementation
- **Portuguese BR**: All user-facing text, API responses, error messages
- **Performance**: Monitor response times, implement caching where needed
- **Security**: OAuth Gov.br required, no hardcoded secrets
- **Constitutional compliance**: Follow TrâmiteJá constitution requirements
- **Free Access**: Platform operates as free public service for all citizens

## Estimated Timeline
- **Phase 3.1 (Setup)**: 2-3 days
- **Phase 3.2 (Tests)**: 3-4 days
- **Phase 3.3 (Core)**: 7-9 days (reduced without payment complexity)
- **Phase 3.4 (Integration)**: 3-4 days
- **Phase 3.5 (Polish)**: 3-4 days
- **Total**: 18-24 days for complete implementation (reduced from 20-26 days)