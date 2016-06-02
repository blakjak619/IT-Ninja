USE master
GO

IF EXISTS ( SELECT  *
            FROM    sys.objects AS o
            WHERE   name = 'fn_BPE_hadr_CheckIfServerIsPrimaryReplica_ByDatabaseName' ) 
    BEGIN
        DROP FUNCTION dbo.fn_BPE_hadr_CheckIfServerIsPrimaryReplica_ByDatabaseName
    END
GO

CREATE FUNCTION dbo.fn_BPE_hadr_CheckIfServerIsPrimaryReplica_ByDatabaseName ( @DBName SYSNAME )
RETURNS BIT
AS 
------------------------------------------------------------------------------------------------
-- Author: Chris Stewart
-- The intent of this function is to identify whether the current server is the principal of a
-- given database.  This is primarily intended for custom, database-specific processes such as
-- the archiving of data from ConstellationEventCapture.
------------------------------------------------------------------------------------------------
BEGIN
    RETURN
    (
        SELECT  'IsPrimary' = CASE WHEN DATABASEPROPERTYEX(d.name, 'UPDATEABILITY') = 'READ_WRITE'
                                        AND state_desc = 'ONLINE' THEN 1
                                   ELSE 0
                              END
        FROM    sys.databases AS d
        WHERE   name = @DBName
    )
END
GO
