# 🍫 CacauApp2 — Visão Computacional Offline + Banco de Dados Seguro e Otimizado

Aplicativo Android nativo desenvolvido para o **CEPEC (Centro de Pesquisa do Cacau) / CEPLAC** para contagem automatizada e monitoramento biométrico/fitossanitário de frutos de cacaueiro (*Theobroma cacao L.*), integrado a uma arquitetura local de **SQL Server 2025 com controle de acesso granular (RBAC), proteção de dados sensíveis (DDM, SHA-256, RLS), índices de cobertura e ponte CLI auditada para IA**.

> **Regras do projeto atendidas:** sem SaaS, site ou aplicação web; dados 100% fictícios/anonimizados; chaves, senhas e modelos `.tflite`/`.pt` fora do repositório.

---

## 🧱 Arquitetura Geral (Evolução desde 27/10)

```
[Câmera Android (CameraX)]
       │
       ▼
[Pré-processamento Letterbox 640x640 + Gamma LUT (cabruca)]
       │
       ▼
[YOLOv8/YOLO11 Offline (.tflite / .pt) + WBF / IoS NMS]
       │
       ▼
[Tela de Revisão Científica (Human-in-the-Loop) + Export CSV pt-BR]
       │
       ▼
[Ponte CLI IA <-> Banco (ia/cacau_ia_db_bridge.py)]  <-- EXECUTE AS USER + Anti-SQLi
       │
       ├──▶ [SQL Server: CacauAppBD (100.000+ linhas)]
       │       ├── RBAC (4 Papéis com GRANT/DENY)
       │       ├── DDM (CPF/E-mail mascarados) + SHA-256
       │       ├── RLS (Row-Level Security por Fazenda)
       │       └── Covering Indexes (Index Seek sem Sort/Lookup)
       │
       └──▶ [dbo.Auditoria_Log (Imutável: quem, o quê, quando, status)]
```

---

## 📲 1. Aplicativo Android (Edge AI Offline)

- **Coleta Livre & Revisão Científica**: câmera ao vivo com detecção contínua, captura em resolução total, toque para remover falsos positivos ou adicionar frutos perdidos e separação entre contagem da IA e contagem final auditada.
- **Modo Rota (FieldBook)**: importação de planilhas CEPLAC (`.csv`) com navegação planta a planta e salto para a próxima pendente.
- **Galeria com Edição & Desfazer**, **Exportação CSV RFC 4180 pt-BR** (delimitador `;`, UTF-8 BOM, proteção contra CSV formula injection) e **Diagnóstico do Sistema** (latência em ms, GPU Delegate/CPU, GPS).

### Política de Privacidade — Modelos de IA (`.tflite` / `.pt`)

> Arquivos `*.tflite`, `*.pt`, `*.onnx`, `.env` e as pastas `modeloia/` e `modelopronto/` estão estritamente bloqueados no `.gitignore`.

1. Copie localmente o modelo para `app/src/main/assets/detector.tflite` (ou importe via menu **Modelo IA** dentro do aplicativo).
2. Copie `.env.example` para `.env` se precisar configurar caminhos/parâmetros locais (nunca versione `.env`).

### Como Compilar e Testar o App Android

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
.\gradlew.bat testDebugUnitTest assembleDebug --no-daemon
```

Suíte unitária em `app/src/test/`: `DetectorLogicUnitTest`, `FieldBookLogicUnitTest`, `FileUtilsUnitTest`, `ModelFormatAndExportUnitTest` e `ExampleUnitTest`.

---

## 🔐 2. Banco de Dados: Segurança e Otimização (SQL Server)

Os scripts em `sql/` constroem o banco `CacauAppBD` com dados sintéticos e validam cada controle de segurança e desempenho:

| Script | Finalidade |
|---|---|
| `sql/00_create_database.sql` | Recriação limpa do banco `CacauAppBD` |
| `sql/01_schema_and_protection.sql` | Tabelas `Fazendas`, `Usuarios` (**DDM** em `cpf`/`email` + **SHA-256**), `Coletas`, `Auditoria_Log` e View `vw_Coletas_Publico_IA` |
| `sql/02_seed_volume.sql` | Carga sintética de **10 fazendas**, **5 usuários** e **100.000 coletas** |
| `sql/03_roles_grant_deny_rls.sql` | Papéis `Tecnico_Campo`, `Auditor_Agronomo`, `Admin_Sistema`, `Role_App_IA`, matriz `GRANT`/`DENY` e **Row-Level Security (`sec.Pol_FiltroFazenda`)** |
| `sql/04_security_verification.sql` | Bateria de **19 testes** automatizados (`EXECUTE AS USER`) provando ALLOW, DENY, DDM e RLS |
| `sql/05_performance_optimization.sql` | Planos de execução (`SHOWPLAN_TEXT`) + `STATISTICS IO/TIME` **antes e depois** de `IX_Coletas_FazendaData` e `IX_Coletas_UsuarioStatusData` |

### Como Executar os Scripts SQL

```powershell
$sqlcmd = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\SQLCMD.EXE"
& $sqlcmd -S localhost -E -C -b -i sql\00_create_database.sql
& $sqlcmd -S localhost -E -C -b -i sql\01_schema_and_protection.sql
& $sqlcmd -S localhost -E -C -b -i sql\02_seed_volume.sql
& $sqlcmd -S localhost -E -C -b -i sql\03_roles_grant_deny_rls.sql
& $sqlcmd -S localhost -E -C -W -i sql\04_security_verification.sql
& $sqlcmd -S localhost -E -C -W -i sql\05_performance_optimization.sql
```

---

## 🤖 3. Visão Computacional, Versionamento e Integração Auditada

A pasta `ia/` concentra os experimentos reprodutíveis de IA e a ponte segura com o SQL Server:

- **Configurações Versionadas**: `ia/configs/pipeline_v1.json` (limiar `0.55`, resize direto, NMS IoU) vs `ia/configs/pipeline_v2.json` (limiar `0.25`, Letterbox `640x640`, Gamma LUT `0.72` para cabruca sombreada, WBF + IoS `0.65` + filtro geométrico).
- **Amostras de Teste Anonimizadas**: `ia/samples/` (6 casos: frutos vermelhos, cacho, amarelos, cacho denso, sub-bosque sombreado e controle negativo).
- **Ponte CLI IA ↔ SQL Server (`ia/cacau_ia_db_bridge.py`)**:
  - Executa inferência `.tflite` offline, grava/consulta no banco sob `EXECUTE AS USER` do perfil solicitante, bloqueia padrões de SQL Injection e grava trilha imutável em `dbo.Auditoria_Log`.
- **Suite Completa de Benchmarks & Gráficos (`ia/run_benchmarks_and_charts.py`)**:
  - Gera automaticamente todas as evidências gráficas em `docs/evidencias/` e o resumo JSON em `docs/evidencias/benchmark_summary.json`.

### Como Rodar a Ponte IA e os Benchmarks (WSL / Python)

```bash
# Exemplo 1: Inferencia offline + gravacao auditada como Role_App_IA
python ia/cacau_ia_db_bridge.py --user usr_app_ia --action infer-and-save --image ia/samples/sample_01_cacau_vermelho.jpg

# Exemplo 2: Teste de bloqueio de permissao via IA (Tecnico tentando ler CPF/Usuarios)
python ia/cacau_ia_db_bridge.py --user usr_tecnico1 --action query --query-type ler_usuarios_pii

# Exemplo 3: Teste de RLS via IA (Tecnico enxerga apenas sua fazenda vinculada)
python ia/cacau_ia_db_bridge.py --user usr_tecnico1 --action query --query-type resumo_fazendas

# Exemplo 4: Consultar trilha de auditoria (apenas Admin_Sistema)
python ia/cacau_ia_db_bridge.py --user usr_admin1 --action audit-tail --limit 10

# Gerar todos os benchmarks e graficos em docs/evidencias/
python ia/run_benchmarks_and_charts.py
```

---

## 🗂️ Estrutura Atualizada do Repositório

```
CacauApp2/
├── app/                          # Aplicativo Android Kotlin + Compose + TFLite + Testes JUnit
├── sql/                          # Scripts SQL Server (Schema, 100k linhas, RBAC, DDM, RLS, Indices)
├── ia/
│   ├── configs/                  # Configuracoes versionadas (pipeline_v1.json, pipeline_v2.json)
│   ├── samples/                  # 6 imagens anonimizadas de teste
│   ├── cacau_ia_db_bridge.py     # Ponte CLI IA <-> SQL Server com RBAC e Auditoria
│   └── run_benchmarks_and_charts.py # Executor de testes, fine-tuning e graficos
├── docs/
│   ├── evidencias/               # Graficos PNG, logs reais de SQL e benchmark_summary.json
│   └── RELATORIO_ENTREGA_17_11.md
├── .env.example                  # Modelo de variaveis locais (segredos fora do Git)
├── .gitignore                    # Bloqueio de .tflite, .pt, .onnx, .env e artefatos temporarios
└── README.md
```

---

## 📄 Licença

Desenvolvido para uso acadêmico e pesquisa junto ao **CEPEC / CEPLAC**. Todos os direitos reservados.
