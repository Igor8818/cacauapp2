-- ============================================================================
-- CacauApp2 - Script 03: Papeis (RBAC), GRANT / DENY e Row-Level Security (RLS)
-- ============================================================================

USE CacauAppBD;
GO

-- 1. Usuarios de banco sem senha hardcoded (autenticacao controlada / EXECUTE AS)
CREATE USER usr_tecnico1 WITHOUT LOGIN;
CREATE USER usr_tecnico2 WITHOUT LOGIN;
CREATE USER usr_auditor1 WITHOUT LOGIN;
CREATE USER usr_admin1   WITHOUT LOGIN;
CREATE USER usr_app_ia   WITHOUT LOGIN;
GO

-- 2. Papeis RBAC
CREATE ROLE Tecnico_Campo;
CREATE ROLE Auditor_Agronomo;
CREATE ROLE Admin_Sistema;
CREATE ROLE Role_App_IA;
GO

ALTER ROLE Tecnico_Campo    ADD MEMBER usr_tecnico1;
ALTER ROLE Tecnico_Campo    ADD MEMBER usr_tecnico2;
ALTER ROLE Auditor_Agronomo ADD MEMBER usr_auditor1;
ALTER ROLE Admin_Sistema    ADD MEMBER usr_admin1;
ALTER ROLE Role_App_IA      ADD MEMBER usr_app_ia;
GO

-- 3. Matriz de Permissoes (GRANT e DENY explicitos)

-- 3.1 Tecnico_Campo: insere/consulta coletas da sua fazenda; NAO altera/apaga coletas, NAO le Usuarios nem Auditoria
GRANT SELECT, INSERT ON dbo.Coletas  TO Tecnico_Campo;
GRANT SELECT         ON dbo.Fazendas TO Tecnico_Campo;
DENY  UPDATE, DELETE ON dbo.Coletas  TO Tecnico_Campo;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.Usuarios      TO Tecnico_Campo;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.Auditoria_Log TO Tecnico_Campo;
GO

-- 3.2 Auditor_Agronomo: consulta coletas/fazendas; aprova status/observacao;
--     Vê Usuarios (com CPF/Email mascarados por DDM!) mas NAO le senha_hash;
--     NAO altera contagens numericas, NAO deleta coletas, NAO acessa Auditoria_Log
GRANT SELECT ON dbo.Coletas  TO Auditor_Agronomo;
GRANT SELECT ON dbo.Fazendas TO Auditor_Agronomo;
GRANT SELECT (id_usuario, nome, login_db, cpf, email, papel, id_fazenda_vinculada, ativo)
    ON dbo.Usuarios TO Auditor_Agronomo;
DENY  SELECT (senha_hash) ON dbo.Usuarios TO Auditor_Agronomo;
GRANT UPDATE (status_validacao, observacao) ON dbo.Coletas TO Auditor_Agronomo;
DENY  UPDATE (qtd_sadios, qtd_vassoura, qtd_podridao, qtd_nao_avaliavel, qtd_total_ia, qtd_total_auditada)
    ON dbo.Coletas TO Auditor_Agronomo;
DENY  DELETE ON dbo.Coletas       TO Auditor_Agronomo;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.Auditoria_Log TO Auditor_Agronomo;
GO

-- 3.3 Admin_Sistema: administra Usuarios/Fazendas, possui UNMASK, consulta/insere Auditoria_Log;
--     PROIBIDO alterar ou apagar Auditoria_Log (imutabilidade) e apagar Coletas
GRANT SELECT, INSERT, UPDATE ON dbo.Usuarios      TO Admin_Sistema;
GRANT SELECT, INSERT, UPDATE ON dbo.Fazendas      TO Admin_Sistema;
GRANT SELECT, INSERT         ON dbo.Auditoria_Log TO Admin_Sistema;
GRANT SELECT                 ON dbo.Coletas       TO Admin_Sistema;
GRANT UNMASK TO Admin_Sistema;
DENY  UPDATE, DELETE ON dbo.Auditoria_Log TO Admin_Sistema;
DENY  DELETE         ON dbo.Coletas       TO Admin_Sistema;
GO

-- 3.4 Role_App_IA: papel restrito da IA - insere contagens, consulta apenas View/Fazendas, grava Auditoria_Log;
--     NEGADO em Usuarios, UPDATE/DELETE Coletas e leitura/alteracao de Auditoria_Log
GRANT INSERT ON dbo.Coletas              TO Role_App_IA;
GRANT SELECT ON dbo.vw_Coletas_Publico_IA TO Role_App_IA;
GRANT SELECT ON dbo.Fazendas             TO Role_App_IA;
GRANT INSERT ON dbo.Auditoria_Log        TO Role_App_IA;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.Usuarios      TO Role_App_IA;
DENY  UPDATE, DELETE                 ON dbo.Coletas       TO Role_App_IA;
DENY  SELECT, UPDATE, DELETE         ON dbo.Auditoria_Log TO Role_App_IA;
GO

-- 4. Row-Level Security (RLS): Tecnico so enxerga a fazenda vinculada ao seu perfil
CREATE FUNCTION sec.fn_FiltroFazendaPorUsuario(@id_fazenda INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS fn_result
    WHERE
        USER_NAME() IN (N'dbo', N'usr_auditor1', N'usr_admin1', N'usr_app_ia')
        OR EXISTS (
            SELECT 1
            FROM sec.Escopo_Fazenda ef
            WHERE ef.login_db = USER_NAME()
              AND (ef.id_fazenda_permitida IS NULL OR ef.id_fazenda_permitida = @id_fazenda)
        )
);
GO

CREATE SECURITY POLICY sec.Pol_FiltroFazenda
    ADD FILTER PREDICATE sec.fn_FiltroFazendaPorUsuario(id_fazenda) ON dbo.Fazendas,
    ADD FILTER PREDICATE sec.fn_FiltroFazendaPorUsuario(id_fazenda) ON dbo.Coletas
WITH (STATE = ON);
GO
