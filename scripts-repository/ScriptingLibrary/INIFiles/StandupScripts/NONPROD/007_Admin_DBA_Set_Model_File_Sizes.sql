USE [master]
GO

IF EXISTS
	(
	SELECT	1
	FROM	sys.master_files mf
	WHERE	mf.database_id = DB_ID('model')
	 AND	mf.name = 'modeldev'
	 AND	mf.size < 131072 -- 1GB
	)
    BEGIN
	ALTER DATABASE [model] MODIFY FILE ( NAME = N'modeldev', SIZE = 1048576KB , FILEGROWTH = 1048576KB )
    END
GO

IF EXISTS
	(
	SELECT	1
	FROM	sys.master_files mf
	WHERE	mf.database_id = DB_ID('model')
	 AND	mf.name = 'modellog'
	 AND	mf.size < 65536 -- 512MB
	)
    BEGIN
	ALTER DATABASE [model] MODIFY FILE ( NAME = N'modellog', SIZE = 524288KB , FILEGROWTH = 524288KB )
    END
GO


--	Revert to Original if needed
/*
USE [master]
GO
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modeldev', SIZE = 1280KB , FILEGROWTH = 1048576KB )
GO
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modellog', SIZE = 512KB , FILEGROWTH = 524288KB )
GO
*/

/*
BPE SQL Servers rely heavily on xp_Commandshell.  So we enable it.
DO NOT run this as a general Post refresh script unless you are sure you need to have CommandShell running.
*/
--EXECUTE SP_CONFIGURE 'show advanced options', 1
--RECONFIGURE WITH OVERRIDE
--GO
 
--EXECUTE SP_CONFIGURE 'xp_cmdshell', '1'
--RECONFIGURE WITH OVERRIDE
--GO
 
--EXECUTE SP_CONFIGURE 'show advanced options', 0
--RECONFIGURE WITH OVERRIDE
--GO