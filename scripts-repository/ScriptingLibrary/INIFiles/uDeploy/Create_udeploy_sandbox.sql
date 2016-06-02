

PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Script begins.'

IF NOT EXISTS
	(
	SELECT	1
	FROM	sys.databases d
	WHERE	d.name = 'udeploy_sandbox'
	)
    BEGIN
	DECLARE @CreatedDBScript NVARCHAR(MAX) = '
		CREATE DATABASE
			[udeploy_sandbox]
				CONTAINMENT = NONE
		ON	PRIMARY 
			(	NAME = N''udeploy_sandbox''
			 ,	FILENAME = N''I:\SQLServer\Data\udeploy_sandbox.mdf''
			 ,	SIZE = 1GB 
			 ,	FILEGROWTH = 1GB
			)          
		LOG ON 	(	NAME = N''udeploy_sandbox_log''
			 ,	FILENAME = N''J:\SQLServer\Log\udeploy_sandbox_log.ldf''
			 ,	SIZE = 512MB 
			 ,	FILEGROWTH = 512MB
			)
		;'

	EXECUTE AS LOGIN = 'sa';
	EXECUTE sp_executesql @CreatedDBScript;
	REVERT;

	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Created database [udeploy_sandbox]'
    END
ELSE
    BEGIN
	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Database [udeploy_sandbox] already exists.'
    END

GO

USE [master]
GO

IF NOT EXISTS
	(
	SELECT	1
	FROM	sys.server_principals sp
	WHERE	sp.name = 'udeploy'
	)
    BEGIN
	CREATE LOGIN
		[udeploy]
	WITH
		PASSWORD = N''			--<<-- Be sure to add the password for this SQL login here  -----------------------------------------------------
	,	DEFAULT_DATABASE = [master]
	,	CHECK_EXPIRATION = OFF
	,	CHECK_POLICY = OFF
	;
	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Created login "udeploy"'
    END
ELSE
    BEGIN
	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Login "udeploy" already exists'
    END
GO

USE [udeploy_sandbox]
GO

IF NOT EXISTS
	(
	SELECT	1
	FROM	sys.database_principals dp
	WHERE	dp.name = 'udeploy'
	)
    BEGIN
	CREATE USER
		[udeploy]
	FOR LOGIN
		[udeploy]

	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Created database user "udeploy" in [udeploy_sandbox]'

    END
ELSE
    BEGIN
	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Database user "udeploy" already exists.'
    END
GO

IF NOT EXISTS
	(
	SELECT	1
	FROM	sys.schemas s
	WHERE	s.name = 'udeploy_sandbox'
	)
    BEGIN
	DECLARE @SQLScript NVARCHAR(1000)

	SET @SQLScript = 'CREATE SCHEMA [udeploy_sandbox] AUTHORIZATION udeploy;'
	EXECUTE sp_executesql @SQLScript

	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Created schema [udeploy_sandbox] for "udeploy".'
    END
ELSE
    BEGIN
	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Schema [udeploy_sandbox] already exists.'
    END

GO

EXECUTE sp_addrolemember 'db_datareader','udeploy';
EXECUTE sp_addrolemember 'db_datawriter','udeploy';
EXECUTE sp_addrolemember 'db_ddladmin','udeploy';

PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Granted user "udeploy" permissions: read & write data, and create/alter/drop objects.'
GO

USE [master]
go

PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Script complete!'
