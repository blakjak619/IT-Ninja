use msdb
go

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SQLDbccAll]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[SQLDbccAll]
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

CREATE PROCEDURE SQLDbccAll 

@indbname sysname = NULL,
@debug bit = 0 -- Default to not run debug

AS

----------------------------------------------------------------------------------------------
-- Author Mark G. Pohto / Microsoft SQL Operations 
-- 08/11/2009: Updated by George Parker for the Bridgepoint environment
----------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
-- 10/23/2012: CStewart - Modified to use sys.databases to take mirroring and snapshots into 
-- account.
------------------------------------------------------------------------------------------------


-- This procedure performs a DBCC on system and user databases.
SET QUOTED_IDENTIFIER ON 
SET ARITHABORT ON
SET ANSI_NULLS ON 
DECLARE @DBName      VARCHAR(100)
       ,@SQLString VARCHAR(255)

-- No database name passed in, run on all available databases

IF ISNULL(@indbname,'0') = '0'
	BEGIN

	DECLARE DB_Cursor CURSOR
	FOR
        SELECT  d.name
        FROM    sys.databases AS d
        WHERE   d.source_database_id IS NULL    -- snapshot databases are not null
                AND d.state_desc = 'ONLINE'  
                AND d.name <> 'tempdb'

		OPEN DB_Cursor

		FETCH NEXT 
		FROM DB_Cursor 
		INTO @DBName 
		 
		WHILE (@@FETCH_STATUS <> -1)
		BEGIN
		   IF (@@FETCH_STATUS <> -2)
		   BEGIN 
			 -- DBCC database 
			 SELECT @SQLString = 'SET QUOTED_IDENTIFIER ON SET ARITHABORT ON  DBCC CHECKDB (['+ @DBName +']) WITH NO_INFOMSGS'
			IF @debug = 1
				BEGIN
					PRINT @SQLString
				END
			IF @debug = 0
				BEGIN
					EXEC  (@SQLString)
				END
		   END

		   FETCH NEXT 
		   FROM DB_Cursor 
		   INTO @DBName     

		END
		CLOSE      DB_Cursor
		DEALLOCATE DB_Cursor
	END


ELSE
	BEGIN
		SELECT @SQLString = 'SET QUOTED_IDENTIFIER ON SET ARITHABORT ON  DBCC CHECKDB (['+ @indbname +']) WITH NO_INFOMSGS'
		IF @debug = 1
			BEGIN
				PRINT @SQLString
			END

		IF @debug = 0
			BEGIN
				EXEC  (@SQLString)
			END
	END

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

