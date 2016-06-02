USE master
GO

IF EXISTS ( SELECT  *
            FROM    sys.sysobjects AS so
            WHERE   so.name = 'BPE_AGMgmt_RemoveDatabaseFromAG' )
    BEGIN
        DROP PROCEDURE
          BPE_AGMgmt_RemoveDatabaseFromAG
    END
          GO
          

CREATE PROCEDURE dbo.BPE_AGMgmt_RemoveDatabaseFromAG
    (
      @AGName VARCHAR(20)
    , @DBName sysname
    )
AS
DECLARE @SQL VARCHAR(1000)

IF dbo.fn_BPE_hadr_CheckIfServerIsPrimaryReplica_ByDatabaseName(@DBName) = 'FALSE'
    BEGIN
        SELECT  @SQL = 'ALTER DATABASE ' + @DBName + ' SET HADR OFF'
    
    END
ELSE
    BEGIN
        SELECT  @SQL = 'ALTER AVAILABILITY GROUP ' + @AGName + ' REMOVE DATABASE ' + @DBName
             
    END

EXEC (@SQL)

GO

--EXEC BPE_AGMgmt_RemoveDatabaseFromAG
--    @AGName = 'waypoint_ag'
--  , @DBName = 'test3'
GO
