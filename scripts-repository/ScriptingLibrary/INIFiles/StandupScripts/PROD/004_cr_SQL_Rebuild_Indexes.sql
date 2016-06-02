USE msdb
GO

/****** Object:  StoredProcedure [dbo].[SQLRebuildIndexes]    Script Date: 08/11/2009 14:59:01 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

IF NOT EXISTS
	(
	SELECT	1
	FROM	sys.procedures p
	WHERE	p.name = 'SQLRebuildIndexes'
	 AND	SCHEMA_NAME(p.[schema_id]) = 'dbo'
	)
    BEGIN
	DECLARE @SQLScript NVARCHAR(MAX) = 'CREATE PROCEDURE dbo.SQLRebuildIndexes AS SELECT ''Hello, world!'' AS MessageToTheWorld;'
	EXECUTE sp_executesql @SQLScript
    END
GO

ALTER PROCEDURE
	dbo.SQLRebuildIndexes
		@indbname SYSNAME = NULL	-- user can specify database, or else will run on all databases
	 ,	@Debug	  BIT 	  = 0		-- Default to not run debug

AS

	/*----------------------------------------------------------------------------------------------
	This procedure, for every available database on this server (or just for the database provided
	in the input parameter), runs a second stored procedure (named master.dbo.rebuild_indexes_by_db)
	which rebuilds all of the indexes in that database

	Change Log:

	08/11/2009:	Created by George Parker for the Bridgepoint environment
	10/23/2012:	CStewart - Modified to use sys.databases to take mirroring and snapshots into
			account.
	2015-04-08:	DJS improves the logic to determine whether or not to include a database in the
			list of databases whose indexes this procedure will rebuild, such that it now
			correctly skips (1) online, read-only databases in standby mode, and (2) 
			secondary replicas in availability groups; also now using DATABASEPROPERTYEX, 
			BECAUSE DATABASEPROPERTY has been officially deprecated; tried very hard not 
			to rewrite this whole thing, but the temptation was irresistible
	----------------------------------------------------------------------------------------------*/

SET QUOTED_IDENTIFIER ON 
SET ARITHABORT ON
SET ANSI_NULLS ON
SET NOCOUNT ON

DECLARE
	@SQLScript	NVARCHAR(255)
 ,	@DatabaseName   NVARCHAR(100)
 ,	@NoWaitMessage  NVARCHAR(255)
;

DECLARE @tb_RebuildIndexesInDatabase TABLE
	(	DatabaseName NVARCHAR(128) PRIMARY KEY CLUSTERED
	)
;

IF @indbname IS NOT NULL
    BEGIN
	INSERT INTO
		@tb_RebuildIndexesInDatabase
	SELECT	d.name
	FROM	sys.databases d
	WHERE	d.name = @indbname
    END
ELSE
    BEGIN
	INSERT INTO
		@tb_RebuildIndexesInDatabase
	SELECT	d.name
	FROM	sys.databases d
	WHERE	DATABASEPROPERTYEX(d.name,'STATUS') = 'ONLINE'
	 AND	DATABASEPROPERTYEX(d.name,'Updateability') = 'READ_WRITE'
	 AND	d.name <> 'tempdb'
	 AND	d.source_database_id IS NULL	-- probably not necessary
    END
;
	 
SELECT  DatabaseName AS [Databases In Which to Rebuild Indexes]
FROM	@tb_RebuildIndexesInDatabase
;

WHILE EXISTS
	(
	SELECT	1
	FROM	@tb_RebuildIndexesInDatabase
	)
    BEGIN
	SELECT	@DatabaseName = MIN(DatabaseName) -- this alphabetizes the task
	FROM	@tb_RebuildIndexesInDatabase

	SET @SQLScript = 'EXECUTE master.dbo.rebuild_indexes_by_db @DBName = ''' + @DatabaseName + ''', @ReorgLimit = 10, @RebuildLimit = 30, @MaxDOP = 2;'
		
	RAISERROR(@SQLScript,0,0) WITH NOWAIT
		
	IF @Debug = 0
		EXECUTE sp_executesql @SQLScript

	DELETE FROM 
		@tb_RebuildIndexesInDatabase
	WHERE	DatabaseName = @DatabaseName
    END

SET QUOTED_IDENTIFIER OFF

GO
