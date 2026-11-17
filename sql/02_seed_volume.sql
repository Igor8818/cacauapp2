-- ============================================================================
-- CacauApp2 - Script 02: Carga inicial + Volume realista (100.000 coletas)
-- Todos os dados sao ficticios/anonimizados para fins academicos.
-- ============================================================================

USE CacauAppBD;
GO
SET NOCOUNT ON;

-- 1. 10 Fazendas ficticias da regiao cacaueira
INSERT INTO dbo.Fazendas (codigo_fazenda, nome_fazenda, municipio_uf, latitude, longitude)
VALUES
('FAZ-01', 'Fazenda Esperanca (Ficticia)',      'Ilheus - BA',    -14.792500, -39.238900),
('FAZ-02', 'Sitio Boa Vista (Ficticio)',        'Itabuna - BA',   -14.801200, -39.251000),
('FAZ-03', 'Estacao Cabruca Sul (Ficticia)',    'Urucuca - BA',   -14.593100, -39.284400),
('FAZ-04', 'Campo Experimental Norte (Fict.)',  'Ilheus - BA',    -14.754000, -39.211000),
('FAZ-05', 'Fazenda Vale do Cacau (Ficticia)',  'Itajuipe - BA',  -14.678900, -39.376500),
('FAZ-06', 'Chacara Amendoa Dourada (Fict.)',   'Camacan - BA',   -15.418200, -39.495600),
('FAZ-07', 'Reserva Cacaueira Leste (Fict.)',   'Una - BA',       -15.293400, -39.075300),
('FAZ-08', 'Fazenda Rio Almada (Ficticia)',     'Coaraci - BA',   -14.640800, -39.551200),
('FAZ-09', 'Sitio Clone Novo (Ficticio)',       'Ubaitaba - BA',  -14.312500, -39.323100),
('FAZ-10', 'Unidade Teste Sul (Fict.)',         'Itabuna - BA',   -14.775100, -39.224800);
GO

-- 2. 5 Usuarios ficticios (CPF ficticio, e-mail ficticio, senha com SHA-256 + salt)
INSERT INTO dbo.Usuarios (nome, login_db, cpf, email, senha_hash, papel, id_fazenda_vinculada)
VALUES
('Tecnico Campo Um (Ficticio)',   'usr_tecnico1', '111.222.333-01', 'tecnico1@cacauapp-ficticio.invalid',
 HASHBYTES('SHA2_256', 'CacauSalt2026#Tec1'), 'Tecnico_Campo', 1),
('Tecnico Campo Dois (Ficticio)', 'usr_tecnico2', '222.333.444-02', 'tecnico2@cacauapp-ficticio.invalid',
 HASHBYTES('SHA2_256', 'CacauSalt2026#Tec2'), 'Tecnico_Campo', 2),
('Auditor Agronomo (Ficticio)',   'usr_auditor1', '333.444.555-03', 'auditor@cacauapp-ficticio.invalid',
 HASHBYTES('SHA2_256', 'CacauSalt2026#Aud1'), 'Auditor_Agronomo', NULL),
('Admin Sistema (Ficticio)',      'usr_admin1',   '444.555.666-04', 'admin@cacauapp-ficticio.invalid',
 HASHBYTES('SHA2_256', 'CacauSalt2026#Adm1'), 'Admin_Sistema', NULL),
('Servico App IA (Sistema)',      'usr_app_ia',   '555.666.777-05', 'ia-service@cacauapp-ficticio.invalid',
 HASHBYTES('SHA2_256', 'CacauSalt2026#IA01'), 'Role_App_IA', NULL);
GO

INSERT INTO sec.Escopo_Fazenda (login_db, id_fazenda_permitida)
SELECT login_db, id_fazenda_vinculada FROM dbo.Usuarios;
GO

-- 3. Carga de volume: 100.000 coletas em lote via matriz decimal 10^5 (zero memory grant)
;WITH D(d) AS (
    SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
),
Nums AS (
    SELECT (a.d * 10000 + b.d * 1000 + c.d * 100 + d.d * 10 + e.d + 1) AS n
    FROM D a CROSS JOIN D b CROSS JOIN D c CROSS JOIN D d CROSS JOIN D e
)
INSERT INTO dbo.Coletas (
    id_fazenda, id_usuario, plant_id, clone, parcela, planta_num,
    data_coleta, qtd_sadios, qtd_vassoura, qtd_podridao, qtd_nao_avaliavel,
    qtd_total_ia, qtd_total_auditada, confianca_media, latencia_ms,
    modelo_ia, status_validacao, observacao
)
SELECT
    ((n - 1) % 10) + 1 AS id_fazenda,
    CASE WHEN (n % 2) = 0 THEN 1 ELSE 2 END AS id_usuario,
    CONCAT(
        CASE (n % 5)
            WHEN 0 THEN 'CCN-51'
            WHEN 1 THEN 'PS-1319'
            WHEN 2 THEN 'CA-02'
            WHEN 3 THEN 'TSH-1188'
            ELSE 'VB-1151'
        END,
        '_P', ((n - 1) % 25) + 1,
        '_Pl', ((n - 1) % 40) + 1
    ) AS plant_id,
    CASE (n % 5)
        WHEN 0 THEN 'CCN-51'
        WHEN 1 THEN 'PS-1319'
        WHEN 2 THEN 'CA-02'
        WHEN 3 THEN 'TSH-1188'
        ELSE 'VB-1151'
    END AS clone,
    ((n - 1) % 25) + 1 AS parcela,
    ((n - 1) % 40) + 1 AS planta_num,
    DATEADD(MINUTE, -1 * (n % 259200), '2026-11-16T12:00:00') AS data_coleta,
    (n % 22) + 1 AS qtd_sadios,
    (n % 4) AS qtd_vassoura,
    (n % 3) AS qtd_podridao,
    (n % 2) AS qtd_nao_avaliavel,
    ((n % 22) + 1) + (n % 4) + (n % 3) + (n % 2) AS qtd_total_ia,
    ((n % 22) + 1) + (n % 4) + (n % 3) + (n % 2) AS qtd_total_auditada,
    CAST(0.7200 + ((n % 25) * 0.0100) AS DECIMAL(5,4)) AS confianca_media,
    75 + (n % 140) AS latencia_ms,
    CASE WHEN (n % 3) = 0 THEN 'best-doenca-yolo11n-ft' ELSE 'detector-cacau-v2.tflite' END AS modelo_ia,
    CASE (n % 4)
        WHEN 0 THEN 'Pendente'
        WHEN 1 THEN 'Validada'
        WHEN 2 THEN 'Validada'
        ELSE 'Revisar'
    END AS status_validacao,
    CASE WHEN (n % 10) = 0 THEN 'Sub-bosque sombreado (Gamma LUT ativo)' ELSE NULL END AS observacao
FROM Nums;
GO

-- 4. Registro inicial de auditoria de carga
INSERT INTO dbo.Auditoria_Log (usuario_solicitante, papel_executado, origem, acao, objeto_alvo, consulta_resumo, status_execucao, detalhe_erro)
VALUES ('dbo', 'Admin_Setup', 'Seed_Inicial', 'SEED_VOLUME', 'dbo.Coletas', 'Carga sintetica inicial de 100.000 coletas ficticias', 'PERMITIDO', NULL);
GO

-- 5. Confirmacao do volume total por tabela
SELECT t.name AS Tabela, SUM(p.rows) AS TotalLinhas
FROM sys.tables t
INNER JOIN sys.partitions p ON t.object_id = p.object_id
WHERE p.index_id IN (0, 1)
  AND t.name IN ('Fazendas', 'Usuarios', 'Coletas', 'Auditoria_Log')
GROUP BY t.name
ORDER BY TotalLinhas DESC;
GO
