-- ============================================================================
-- CacauApp2 - Script 05: Consultas Lentas, Planos de Execucao e Otimizacao
-- ============================================================================

USE CacauAppBD;
GO

-- Garantir estado limpo (remover indices nao clusterizados caso ja existam)
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Coletas_FazendaData' AND object_id = OBJECT_ID(N'dbo.Coletas'))
    DROP INDEX IX_Coletas_FazendaData ON dbo.Coletas;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Coletas_UsuarioStatusData' AND object_id = OBJECT_ID(N'dbo.Coletas'))
    DROP INDEX IX_Coletas_UsuarioStatusData ON dbo.Coletas;
GO

-- ============================================================================
-- FASE 1: ANTES DOS INDICES (Baseline Lento)
-- ============================================================================
PRINT '=== PLANO DE EXECUCAO - ANTES DOS INDICES ===';
GO
SET SHOWPLAN_TEXT ON;
GO
-- Consulta Lenta 1: Soma de frutos sadios/doentes por fazenda e janela recente
SELECT id_fazenda, clone,
       COUNT(*) AS total_registros,
       SUM(qtd_sadios) AS total_sadios,
       SUM(qtd_vassoura) AS total_vassoura,
       SUM(qtd_podridao) AS total_podridao
FROM dbo.Coletas
WHERE id_fazenda = 3
  AND data_coleta >= '2026-09-01T00:00:00'
GROUP BY id_fazenda, clone;
GO
-- Consulta Lenta 2: Historico recente pendente de tecnico ordenado por data (gera Scan + Sort)
SELECT TOP 100 id_coleta, plant_id, data_coleta, qtd_total_ia, qtd_total_auditada
FROM dbo.Coletas
WHERE id_usuario = 1
  AND status_validacao = 'Pendente'
ORDER BY data_coleta DESC;
GO
SET SHOWPLAN_TEXT OFF;
GO

PRINT '=== METRICAS IO / TEMPO - ANTES DOS INDICES ===';
DBCC DROPCLEANBUFFERS;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT id_fazenda, clone,
       COUNT(*) AS total_registros,
       SUM(qtd_sadios) AS total_sadios,
       SUM(qtd_vassoura) AS total_vassoura,
       SUM(qtd_podridao) AS total_podridao
FROM dbo.Coletas
WHERE id_fazenda = 3
  AND data_coleta >= '2026-09-01T00:00:00'
GROUP BY id_fazenda, clone;
GO
SELECT TOP 100 id_coleta, plant_id, data_coleta, qtd_total_ia, qtd_total_auditada
FROM dbo.Coletas
WHERE id_usuario = 1
  AND status_validacao = 'Pendente'
ORDER BY data_coleta DESC;
GO
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-- ============================================================================
-- FASE 2: CRIACAO DE INDICES COMPOSTOS COM INCLUDE (Covering Indexes)
-- ============================================================================
PRINT '=== CRIANDO INDICES DE OTIMIZACAO ===';
CREATE NONCLUSTERED INDEX IX_Coletas_FazendaData
    ON dbo.Coletas (id_fazenda, data_coleta)
    INCLUDE (clone, qtd_sadios, qtd_vassoura, qtd_podridao);

CREATE NONCLUSTERED INDEX IX_Coletas_UsuarioStatusData
    ON dbo.Coletas (id_usuario, status_validacao, data_coleta DESC)
    INCLUDE (id_fazenda, plant_id, qtd_total_ia, qtd_total_auditada);
GO

-- ============================================================================
-- FASE 3: DEPOIS DOS INDICES (Otimizado)
-- ============================================================================
PRINT '=== PLANO DE EXECUCAO - DEPOIS DOS INDICES ===';
GO
SET SHOWPLAN_TEXT ON;
GO
SELECT id_fazenda, clone,
       COUNT(*) AS total_registros,
       SUM(qtd_sadios) AS total_sadios,
       SUM(qtd_vassoura) AS total_vassoura,
       SUM(qtd_podridao) AS total_podridao
FROM dbo.Coletas
WHERE id_fazenda = 3
  AND data_coleta >= '2026-09-01T00:00:00'
GROUP BY id_fazenda, clone;
GO
SELECT TOP 100 id_coleta, plant_id, data_coleta, qtd_total_ia, qtd_total_auditada
FROM dbo.Coletas
WHERE id_usuario = 1
  AND status_validacao = 'Pendente'
ORDER BY data_coleta DESC;
GO
SET SHOWPLAN_TEXT OFF;
GO

PRINT '=== METRICAS IO / TEMPO - DEPOIS DOS INDICES ===';
DBCC DROPCLEANBUFFERS;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO
SELECT id_fazenda, clone,
       COUNT(*) AS total_registros,
       SUM(qtd_sadios) AS total_sadios,
       SUM(qtd_vassoura) AS total_vassoura,
       SUM(qtd_podridao) AS total_podridao
FROM dbo.Coletas
WHERE id_fazenda = 3
  AND data_coleta >= '2026-09-01T00:00:00'
GROUP BY id_fazenda, clone;
GO
SELECT TOP 100 id_coleta, plant_id, data_coleta, qtd_total_ia, qtd_total_auditada
FROM dbo.Coletas
WHERE id_usuario = 1
  AND status_validacao = 'Pendente'
ORDER BY data_coleta DESC;
GO
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
