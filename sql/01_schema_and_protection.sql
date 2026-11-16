-- ============================================================================
-- CacauApp2 - Script 01: Schema, Tabelas, Dynamic Data Masking (DDM) e View
-- ============================================================================

USE CacauAppBD;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'sec')
    EXEC(N'CREATE SCHEMA sec AUTHORIZATION dbo;');
GO

-- 1. Fazendas experimentais (ficticias)
CREATE TABLE dbo.Fazendas (
    id_fazenda      INT IDENTITY(1,1) PRIMARY KEY,
    codigo_fazenda  VARCHAR(20)  NOT NULL UNIQUE,
    nome_fazenda    VARCHAR(120) NOT NULL,
    municipio_uf    VARCHAR(80)  NOT NULL,
    latitude        DECIMAL(9,6) NOT NULL,
    longitude       DECIMAL(9,6) NOT NULL,
    ativa           BIT          NOT NULL DEFAULT 1
);
GO

-- 2. Usuarios com dados sensiveis protegidos por DDM + Hash SHA-256
CREATE TABLE dbo.Usuarios (
    id_usuario            INT IDENTITY(1,1) PRIMARY KEY,
    nome                  VARCHAR(120) NOT NULL,
    login_db              SYSNAME      NOT NULL UNIQUE,
    cpf                   CHAR(14)     MASKED WITH (FUNCTION = 'partial(3,".***.***-",2)') NOT NULL,
    email                 VARCHAR(120) MASKED WITH (FUNCTION = 'email()') NOT NULL,
    senha_hash            VARBINARY(32) NOT NULL,
    papel                 VARCHAR(40)  NOT NULL,
    id_fazenda_vinculada  INT          NULL REFERENCES dbo.Fazendas(id_fazenda),
    ativo                 BIT          NOT NULL DEFAULT 1,
    criado_em             DATETIME2    NOT NULL DEFAULT SYSDATETIME()
);
GO

-- 3. Coletas de campo (contagem + fitossanidade via Visao Computacional e Auditoria)
CREATE TABLE dbo.Coletas (
    id_coleta           BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_fazenda          INT          NOT NULL REFERENCES dbo.Fazendas(id_fazenda),
    id_usuario          INT          NOT NULL REFERENCES dbo.Usuarios(id_usuario),
    plant_id            VARCHAR(60)  NOT NULL,
    clone               VARCHAR(30)  NOT NULL,
    parcela             INT          NOT NULL,
    planta_num          INT          NOT NULL,
    data_coleta         DATETIME2    NOT NULL DEFAULT SYSDATETIME(),
    qtd_sadios          INT          NOT NULL,
    qtd_vassoura        INT          NOT NULL,
    qtd_podridao        INT          NOT NULL,
    qtd_nao_avaliavel   INT          NOT NULL DEFAULT 0,
    qtd_total_ia        INT          NOT NULL,
    qtd_total_auditada  INT          NOT NULL,
    confianca_media     DECIMAL(5,4) NOT NULL,
    latencia_ms         INT          NOT NULL,
    modelo_ia           VARCHAR(80)  NOT NULL,
    status_validacao    VARCHAR(25)  NOT NULL DEFAULT 'Pendente',
    observacao          VARCHAR(200) NULL
);
GO

-- 4. Log imutavel de Auditoria (quem consultou, o que consultou, quando e resultado)
CREATE TABLE dbo.Auditoria_Log (
    id_log              BIGINT IDENTITY(1,1) PRIMARY KEY,
    data_hora           DATETIME2    NOT NULL DEFAULT SYSDATETIME(),
    usuario_solicitante SYSNAME      NOT NULL,
    papel_executado     VARCHAR(50)  NOT NULL,
    origem              VARCHAR(40)  NOT NULL,
    acao                VARCHAR(40)  NOT NULL,
    objeto_alvo         VARCHAR(80)  NOT NULL,
    consulta_resumo     VARCHAR(300) NOT NULL,
    status_execucao     VARCHAR(20)  NOT NULL,
    detalhe_erro        VARCHAR(300) NULL
);
GO

-- 5. View segura para a IA ler apenas metricas agronomicas (zero PII)
CREATE VIEW dbo.vw_Coletas_Publico_IA
AS
SELECT
    c.id_coleta,
    c.id_fazenda,
    f.codigo_fazenda,
    f.nome_fazenda,
    c.plant_id,
    c.clone,
    c.parcela,
    c.planta_num,
    c.data_coleta,
    c.qtd_sadios,
    c.qtd_vassoura,
    c.qtd_podridao,
    c.qtd_nao_avaliavel,
    c.qtd_total_ia,
    c.qtd_total_auditada,
    c.confianca_media,
    c.latencia_ms,
    c.modelo_ia,
    c.status_validacao
FROM dbo.Coletas c
INNER JOIN dbo.Fazendas f ON f.id_fazenda = c.id_fazenda;
GO

-- 6. Tabela auxiliar para RLS (mapeamento seguro login -> fazenda permitida)
CREATE TABLE sec.Escopo_Fazenda (
    login_db             SYSNAME PRIMARY KEY,
    id_fazenda_permitida INT NULL -- NULL significa acesso a todas as fazendas
);
GO
