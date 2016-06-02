

PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Script begins.'

IF NOT EXISTS
	(
	SELECT	1
	FROM	sys.databases d
	WHERE	d.name = 'udeploy'
	)
    BEGIN
	DECLARE @CreatedDBScript NVARCHAR(MAX) = '
		CREATE DATABASE
			[udeploy]
				CONTAINMENT = NONE
		ON	PRIMARY 
			(	NAME = N''udeploy''
			 ,	FILENAME = N''I:\SQLServer\Data\udeploy.mdf''
			 ,	SIZE = 1GB 
			 ,	FILEGROWTH = 1GB
			)          
		LOG ON 	(	NAME = N''udeploy_log''
			 ,	FILENAME = N''J:\SQLServer\Log\udeploy_log.ldf''
			 ,	SIZE = 512MB 
			 ,	FILEGROWTH = 512MB
			)
		;'

	EXECUTE AS LOGIN = 'sa';
	EXECUTE sp_executesql @CreatedDBScript;
	REVERT;

	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Created database [udeploy]'
    END
ELSE
    BEGIN
	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Database [udeploy] already exists.'
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

USE [udeploy]
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

	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Created database user "udeploy" in [udeploy]'

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
	WHERE	s.name = 'udeploy'
	)
    BEGIN
	DECLARE @SQLScript NVARCHAR(1000)

	SET @SQLScript = 'CREATE SCHEMA [udeploy] AUTHORIZATION udeploy;'
	EXECUTE sp_executesql @SQLScript

	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Created schema [udeploy] for "udeploy".'
    END
ELSE
    BEGIN
	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Schema [udeploy] already exists.'
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
