-- ============================================================================
-- CacauApp2 - Script 00: Criacao limpa do banco de dados CacauAppBD
-- Ambiente: Microsoft SQL Server 2025 (localhost)
-- Regra de projeto: Dados 100% ficticios / anonimizados
-- ============================================================================

USE master;
GO

IF DB_ID(N'CacauAppBD') IS NOT NULL
BEGIN
    ALTER DATABASE CacauAppBD SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CacauAppBD;
END
GO

CREATE DATABASE CacauAppBD;
GO

USE CacauAppBD;
GO

SELECT DB_NAME() AS BancoAtivo, SUSER_SNAME() AS ExecutadoPor, SYSDATETIME() AS CriadoEm;
GO
