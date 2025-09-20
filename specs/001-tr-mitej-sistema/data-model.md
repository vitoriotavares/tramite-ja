# Data Model: TrâmiteJá

## Entity Relationships

```
Cidadao (1) --- (N) Processo
Processo (1) --- (1) Relator
Processo (1) --- (N) Voto
Voto (N) --- (1) Julgador
Processo (1) --- (N) Documento
Processo (1) --- (N) Notificacao
```

## Entities

### Processo (Defense Case)
**Primary Entity**: Represents a traffic defense case in the system
- `id`: UUID, Primary Key
- `codigo_acompanhamento`: String(12), Unique tracking code for citizens
- `tipo_infracao`: Enum('velocidade', 'rodizio', 'semaforo')
- `status`: Enum('rascunho', 'triagem', 'distribuido', 'em_analise', 'em_votacao', 'decidido', 'rejeitado')
- `cidadao_id`: UUID, Foreign Key to Cidadao
- `relator_id`: UUID, Foreign Key to Relator (nullable until distribution)
- `data_criacao`: DateTime
- `data_limite`: DateTime (30 days from creation)
- `data_decisao`: DateTime (nullable)
- `parecer_relator`: Text (nullable)
- `decisao_final`: Enum('deferido', 'indeferido') (nullable)
- `justificativa_rejeicao`: Text (nullable for triage rejections)

**Validations**:
- `codigo_acompanhamento` must be unique and auto-generated
- `data_limite` must be within 30 days of creation
- Process must complete within 5 days of approval
- `parecer_relator` required when status = 'em_votacao'

**State Transitions**:
- rascunho → triagem → distribuido → em_analise → em_votacao → decidido
- triagem → rejeitado (if documentation fails)

### Cidadao (Citizen)
**Description**: Person submitting traffic defense
- `id`: UUID, Primary Key
- `cpf`: String(11), Unique identifier
- `nome_completo`: String(255)
- `email`: String(255)
- `telefone`: String(15)
- `endereco_completo`: Text
- `oauth_gov_id`: String(255), Gov.br OAuth identifier
- `data_cadastro`: DateTime

**Validations**:
- `cpf` must be valid and unique
- `email` must be valid format
- OAuth integration required for identity verification

### Relator (Legal Reviewer)
**Description**: Legal professional who analyzes cases
- `id`: UUID, Primary Key
- `nome`: String(255)
- `registro_oab`: String(20), Unique
- `email`: String(255)
- `especializacoes`: Array of Enum('velocidade', 'rodizio', 'semaforo', 'geral')
- `capacidade_maxima`: Integer (default: 10)
- `processos_ativos`: Integer (default: 0)
- `disponivel`: Boolean (default: true)
- `metricas_performance`: JSON (avg_time, decision_rate, etc.)
- `data_cadastro`: DateTime

**Validations**:
- `registro_oab` must be valid format
- `capacidade_maxima` must be > 0
- `processos_ativos` must be <= `capacidade_maxima`

### Julgador (Judge)
**Description**: Voting member of collegial body
- `id`: UUID, Primary Key
- `nome`: String(255)
- `registro_profissional`: String(20)
- `email`: String(255)
- `especializacoes`: Array of Enum('velocidade', 'rodizio', 'semaforo', 'geral')
- `disponivel`: Boolean (default: true)
- `historico_votos`: JSON (statistics)
- `data_cadastro`: DateTime

**Validations**:
- `registro_profissional` must be unique
- Must have at least one specialization

### Voto (Vote)
**Description**: Individual judge decision in collegial voting
- `id`: UUID, Primary Key
- `processo_id`: UUID, Foreign Key to Processo
- `julgador_id`: UUID, Foreign Key to Julgador
- `decisao`: Enum('concordo', 'discordo')
- `justificativa`: Text (optional)
- `data_voto`: DateTime
- `tempo_analise`: Integer (minutes spent reviewing)

**Validations**:
- Only one vote per judge per process
- `justificativa` recommended for 'discordo' votes
- Automatic quorum calculation when votes >= 3

### Documento (Document)
**Description**: Uploaded files with classification and validation
- `id`: UUID, Primary Key
- `processo_id`: UUID, Foreign Key to Processo
- `tipo`: Enum('cnh', 'crlv', 'comprovante', 'outros')
- `nome_arquivo`: String(255)
- `url_armazenamento`: String(500) (R2 Cloudflare URL)
- `tamanho_bytes`: BigInteger
- `tipo_mime`: String(100)
- `status_validacao`: Enum('pendente', 'aprovado', 'rejeitado')
- `motivo_rejeicao`: Text (nullable)
- `data_upload`: DateTime

**Validations**:
- File size limit: 10MB per document
- Allowed MIME types: PDF, JPG, PNG
- Required documents: CNH, CRLV based on violation type

### Notificacao (Notification)
**Description**: Communication record with recipients
- `id`: UUID, Primary Key
- `processo_id`: UUID, Foreign Key to Processo
- `destinatario_email`: String(255)
- `tipo`: Enum('criacao', 'triagem', 'distribuicao', 'analise', 'votacao', 'decisao')
- `assunto`: String(255)
- `conteudo`: Text
- `status_envio`: Enum('pendente', 'enviado', 'falhado')
- `data_criacao`: DateTime
- `data_envio`: DateTime (nullable)
- `tentativas`: Integer (default: 0)

**Validations**:
- Email format validation
- Maximum 3 retry attempts for failed notifications
- Templates for each notification type in Portuguese

## Business Rules

### Distribution Algorithm
1. Filter reviewers by specialization (if violation-specific)
2. Filter by availability and capacity
3. Sort by current workload (ascending)
4. Assign to reviewer with lowest workload
5. Update reviewer's `processos_ativos` counter

### Voting Quorum
- Minimum 3 judges required for decision
- Simple majority (50% + 1) determines outcome
- Automatic decision generation when quorum reached
- Reviewer's opinion serves as default if tie (rare with odd numbers)

### Timeline Enforcement
- 30-day legal deadline from violation date
- 5-day processing deadline from process submission
- Automatic alerts at 80% of deadline
- Automatic escalation for deadline breaches

### Document Validation Rules
- CNH: Required for all violation types
- CRLV: Required for vehicle-related infractions
- Supporting evidence: Optional but recommended
- File format validation on upload
- Virus scanning before storage

### Free Public Access Model
1. **Free Access**: No payment required for platform access
2. **Process Flow**: Citizen submits process → Triage → Distribution → Analysis → Voting → Decision
3. **Public Service**: Platform operates as free public service for all citizens
4. **Cost Management**: Platform operational costs managed through government funding or institutional support