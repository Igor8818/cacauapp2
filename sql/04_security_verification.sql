-- ============================================================================
-- CacauApp2 - Script 04: Bateria de Testes de Seguranca (ALLOW / DENY / DDM / RLS)
-- ============================================================================

USE CacauAppBD;
GO
SET NOCOUNT ON;

PRINT '=== 1. VERIFICACAO DE DYNAMIC DATA MASKING (DDM) & SHA-256 ===';
EXECUTE AS USER = 'usr_auditor1';
SELECT TOP 3
    id_usuario,
    nome,
    cpf   AS cpf_mascarado_auditor,
    email AS email_mascarado_auditor,
    papel
FROM dbo.Usuarios
ORDER BY id_usuario;
REVERT;
GO

EXECUTE AS USER = 'usr_admin1';
SELECT TOP 3
    id_usuario,
    nome,
    cpf   AS cpf_desmascarado_admin,
    email AS email_desmascarado_admin,
    CONVERT(VARCHAR(64), senha_hash, 2) AS sha256_hex
FROM dbo.Usuarios
ORDER BY id_usuario;
REVERT;
GO

PRINT '=== 2. VERIFICACAO DE ROW-LEVEL SECURITY (RLS) ===';
EXECUTE AS USER = 'usr_tecnico1';
SELECT USER_NAME() AS PerfilAtual,
       (SELECT COUNT(*) FROM dbo.Fazendas) AS FazendasVisiveis,
       (SELECT STRING_AGG(codigo_fazenda, ', ') FROM dbo.Fazendas) AS CodigosVisiveis,
       (SELECT COUNT(*) FROM dbo.Coletas) AS ColetasVisiveis;
REVERT;
GO

EXECUTE AS USER = 'usr_tecnico2';
SELECT USER_NAME() AS PerfilAtual,
       (SELECT COUNT(*) FROM dbo.Fazendas) AS FazendasVisiveis,
       (SELECT STRING_AGG(codigo_fazenda, ', ') FROM dbo.Fazendas) AS CodigosVisiveis,
       (SELECT COUNT(*) FROM dbo.Coletas) AS ColetasVisiveis;
REVERT;
GO

EXECUTE AS USER = 'usr_auditor1';
SELECT USER_NAME() AS PerfilAtual,
       (SELECT COUNT(*) FROM dbo.Fazendas) AS FazendasVisiveis,
       (SELECT COUNT(*) FROM dbo.Coletas) AS ColetasVisiveis;
REVERT;
GO

PRINT '=== 3. TESTES EXPLICITOS DE ALLOW / DENY POR PAPEL ===';

-- Helper inline tests com TRY/CATCH para registrar PERMITIDO vs NEGADO
CREATE TABLE #ResultadosSeguranca (
    id_teste        INT IDENTITY(1,1) PRIMARY KEY,
    papel           VARCHAR(30),
    usuario         VARCHAR(30),
    objeto          VARCHAR(60),
    operacao        VARCHAR(40),
    esperado        VARCHAR(20),
    obtido          VARCHAR(20),
    detalhe         VARCHAR(250)
);
GO

-- 3.1 Tecnico_Campo (usr_tecnico1)
BEGIN TRY
    EXECUTE AS USER = 'usr_tecnico1';
    DECLARE @c1 INT = (SELECT COUNT(*) FROM dbo.Coletas);
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Tecnico_Campo', 'usr_tecnico1', 'dbo.Coletas', 'SELECT (com RLS)', 'ALLOW', 'ALLOW', CONCAT('Retornou ', @c1, ' linhas (apenas Fazenda 1)'));
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Tecnico_Campo', 'usr_tecnico1', 'dbo.Coletas', 'SELECT (com RLS)', 'ALLOW', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_tecnico1';
    INSERT INTO dbo.Coletas (id_fazenda, id_usuario, plant_id, clone, parcela, planta_num, qtd_sadios, qtd_vassoura, qtd_podridao, qtd_total_ia, qtd_total_auditada, confianca_media, latencia_ms, modelo_ia)
    VALUES (1, 1, 'CCN-51_P1_Pl99', 'CCN-51', 1, 99, 10, 0, 0, 10, 10, 0.9100, 95, 'detector-cacau-v2.tflite');
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Tecnico_Campo', 'usr_tecnico1', 'dbo.Coletas', 'INSERT', 'ALLOW', 'ALLOW', 'Insercao de coleta permitida');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Tecnico_Campo', 'usr_tecnico1', 'dbo.Coletas', 'INSERT', 'ALLOW', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_tecnico1';
    UPDATE dbo.Coletas SET qtd_sadios = 999 WHERE id_coleta = 1;
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Tecnico_Campo', 'usr_tecnico1', 'dbo.Coletas', 'UPDATE', 'DENY', 'ALLOW', 'ERRO: alteracao foi permitida');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Tecnico_Campo', 'usr_tecnico1', 'dbo.Coletas', 'UPDATE', 'DENY', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_tecnico1';
    DELETE FROM dbo.Coletas WHERE id_coleta = 1;
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Tecnico_Campo', 'usr_tecnico1', 'dbo.Coletas', 'DELETE', 'DENY', 'ALLOW', 'ERRO: exclusao foi permitida');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Tecnico_Campo', 'usr_tecnico1', 'dbo.Coletas', 'DELETE', 'DENY', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_tecnico1';
    DECLARE @u1 INT = (SELECT COUNT(*) FROM dbo.Usuarios);
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Tecnico_Campo', 'usr_tecnico1', 'dbo.Usuarios', 'SELECT', 'DENY', 'ALLOW', 'ERRO: leitura de usuarios permitida');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Tecnico_Campo', 'usr_tecnico1', 'dbo.Usuarios', 'SELECT', 'DENY', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_tecnico1';
    DECLARE @a1 INT = (SELECT COUNT(*) FROM dbo.Auditoria_Log);
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Tecnico_Campo', 'usr_tecnico1', 'dbo.Auditoria_Log', 'SELECT', 'DENY', 'ALLOW', 'ERRO: leitura de auditoria permitida');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Tecnico_Campo', 'usr_tecnico1', 'dbo.Auditoria_Log', 'SELECT', 'DENY', 'DENY', ERROR_MESSAGE());
END CATCH;

-- 3.2 Auditor_Agronomo (usr_auditor1)
BEGIN TRY
    EXECUTE AS USER = 'usr_auditor1';
    DECLARE @cpf_aud VARCHAR(20) = (SELECT TOP 1 cpf FROM dbo.Usuarios WHERE id_usuario = 1);
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Auditor_Agronomo', 'usr_auditor1', 'dbo.Usuarios.cpf', 'SELECT (DDM)', 'MASKED', 'MASKED', CONCAT('CPF retornado: ', @cpf_aud));
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Auditor_Agronomo', 'usr_auditor1', 'dbo.Usuarios.cpf', 'SELECT (DDM)', 'MASKED', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_auditor1';
    DECLARE @sh VARBINARY(32) = (SELECT TOP 1 senha_hash FROM dbo.Usuarios);
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Auditor_Agronomo', 'usr_auditor1', 'dbo.Usuarios.senha_hash', 'SELECT', 'DENY', 'ALLOW', 'ERRO: hash lido');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Auditor_Agronomo', 'usr_auditor1', 'dbo.Usuarios.senha_hash', 'SELECT', 'DENY', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_auditor1';
    UPDATE dbo.Coletas SET status_validacao = 'Validada', observacao = 'Aprovada em auditoria' WHERE id_coleta = 1;
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Auditor_Agronomo', 'usr_auditor1', 'dbo.Coletas.status_validacao', 'UPDATE', 'ALLOW', 'ALLOW', 'Status de validacao atualizado');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Auditor_Agronomo', 'usr_auditor1', 'dbo.Coletas.status_validacao', 'UPDATE', 'ALLOW', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_auditor1';
    UPDATE dbo.Coletas SET qtd_sadios = 99 WHERE id_coleta = 1;
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Auditor_Agronomo', 'usr_auditor1', 'dbo.Coletas.qtd_sadios', 'UPDATE', 'DENY', 'ALLOW', 'ERRO: alteracao de contagem permitida');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Auditor_Agronomo', 'usr_auditor1', 'dbo.Coletas.qtd_sadios', 'UPDATE', 'DENY', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_auditor1';
    DELETE FROM dbo.Coletas WHERE id_coleta = 1;
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Auditor_Agronomo', 'usr_auditor1', 'dbo.Coletas', 'DELETE', 'DENY', 'ALLOW', 'ERRO: delete permitido');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Auditor_Agronomo', 'usr_auditor1', 'dbo.Coletas', 'DELETE', 'DENY', 'DENY', ERROR_MESSAGE());
END CATCH;

-- 3.3 Admin_Sistema (usr_admin1)
BEGIN TRY
    EXECUTE AS USER = 'usr_admin1';
    DECLARE @cpf_adm VARCHAR(20) = (SELECT TOP 1 cpf FROM dbo.Usuarios WHERE id_usuario = 1);
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Admin_Sistema', 'usr_admin1', 'dbo.Usuarios.cpf', 'SELECT (UNMASK)', 'ALLOW', 'ALLOW', CONCAT('CPF real autorizado: ', @cpf_adm));
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Admin_Sistema', 'usr_admin1', 'dbo.Usuarios.cpf', 'SELECT (UNMASK)', 'ALLOW', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_admin1';
    DECLARE @a_adm INT = (SELECT COUNT(*) FROM dbo.Auditoria_Log);
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Admin_Sistema', 'usr_admin1', 'dbo.Auditoria_Log', 'SELECT', 'ALLOW', 'ALLOW', CONCAT('Logs visiveis: ', @a_adm));
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Admin_Sistema', 'usr_admin1', 'dbo.Auditoria_Log', 'SELECT', 'ALLOW', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_admin1';
    DELETE FROM dbo.Auditoria_Log WHERE id_log = 1;
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Admin_Sistema', 'usr_admin1', 'dbo.Auditoria_Log', 'DELETE', 'DENY', 'ALLOW', 'ERRO: auditoria apagada');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Admin_Sistema', 'usr_admin1', 'dbo.Auditoria_Log', 'DELETE', 'DENY', 'DENY', ERROR_MESSAGE());
END CATCH;

-- 3.4 Role_App_IA (usr_app_ia)
BEGIN TRY
    EXECUTE AS USER = 'usr_app_ia';
    DECLARE @vw INT = (SELECT COUNT(*) FROM dbo.vw_Coletas_Publico_IA);
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Role_App_IA', 'usr_app_ia', 'dbo.vw_Coletas_Publico_IA', 'SELECT', 'ALLOW', 'ALLOW', CONCAT('Registros agronomicos sem PII: ', @vw));
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Role_App_IA', 'usr_app_ia', 'dbo.vw_Coletas_Publico_IA', 'SELECT', 'ALLOW', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_app_ia';
    INSERT INTO dbo.Coletas (id_fazenda, id_usuario, plant_id, clone, parcela, planta_num, qtd_sadios, qtd_vassoura, qtd_podridao, qtd_total_ia, qtd_total_auditada, confianca_media, latencia_ms, modelo_ia)
    VALUES (1, 5, 'PS-1319_P2_Pl10', 'PS-1319', 2, 10, 8, 1, 0, 9, 9, 0.8900, 102, 'best-doenca-yolo11n-ft');
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Role_App_IA', 'usr_app_ia', 'dbo.Coletas', 'INSERT', 'ALLOW', 'ALLOW', 'IA gravou contagem inferida');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Role_App_IA', 'usr_app_ia', 'dbo.Coletas', 'INSERT', 'ALLOW', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_app_ia';
    DECLARE @u_ia INT = (SELECT COUNT(*) FROM dbo.Usuarios);
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Role_App_IA', 'usr_app_ia', 'dbo.Usuarios', 'SELECT', 'DENY', 'ALLOW', 'ERRO: IA acessou PII');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Role_App_IA', 'usr_app_ia', 'dbo.Usuarios', 'SELECT', 'DENY', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_app_ia';
    DELETE FROM dbo.Coletas WHERE id_coleta = 1;
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Role_App_IA', 'usr_app_ia', 'dbo.Coletas', 'DELETE', 'DENY', 'ALLOW', 'ERRO: IA apagou coleta');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Role_App_IA', 'usr_app_ia', 'dbo.Coletas', 'DELETE', 'DENY', 'DENY', ERROR_MESSAGE());
END CATCH;

BEGIN TRY
    EXECUTE AS USER = 'usr_app_ia';
    DECLARE @a_ia INT = (SELECT COUNT(*) FROM dbo.Auditoria_Log);
    REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Role_App_IA', 'usr_app_ia', 'dbo.Auditoria_Log', 'SELECT', 'DENY', 'ALLOW', 'ERRO: IA leu log');
END TRY
BEGIN CATCH
    IF USER_NAME() <> 'dbo' REVERT;
    INSERT INTO #ResultadosSeguranca VALUES ('Role_App_IA', 'usr_app_ia', 'dbo.Auditoria_Log', 'SELECT', 'DENY', 'DENY', ERROR_MESSAGE());
END CATCH;

SELECT id_teste, papel, usuario, objeto, operacao, esperado, obtido, detalhe
FROM #ResultadosSeguranca
ORDER BY id_teste;
GO
