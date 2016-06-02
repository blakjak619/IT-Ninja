USE master
GO

IF EXISTS ( SELECT  *
            FROM    sys.sysobjects AS so
            WHERE   so.name = 'fn_BPE_GetAGPreferredReplica' )
    BEGIN
        DROP FUNCTION dbo.fn_BPE_GetAGPreferredReplica  
    END
GO

CREATE FUNCTION dbo.fn_BPE_GetAGPreferredReplica ( @AGName VARCHAR(100) )
RETURNS @AGInfo TABLE
    (
      AGName VARCHAR(100)
    , PreferredReplicaName VARCHAR(20)
    )
AS
BEGIN
    SELECT  @AGName = ISNULL(@AGName, '%')

    INSERT  INTO @AGInfo
            SELECT  AGInfo.NAME
                  , AGInfo.replica_server_name
            FROM    (
                      SELECT    ag.NAME
                              , ar.replica_server_name
                              , rownum = ROW_NUMBER() OVER ( PARTITION BY ag.NAME ORDER BY ar.BACKUP_PRIORITY DESC )
                      FROM      sys.availability_groups AS ag
                                INNER JOIN sys.availability_replicas AS ar
                                    ON ar.group_id = ag.group_id
                      WHERE     ag.NAME LIKE @AGName
                    ) AS AGInfo
            WHERE   AGInfo.rownum = 1

    RETURN 	
END
GO


--SELECT  fbgapn.PreferredReplicaName
--FROM    fn_BPE_GetAGPreferredReplica('WAYPOINT_AG') AS fbgapn


--SELECT  *
--            FROM    sys.sysobjects AS so
--            WHERE   so.name LIKE 'fn_BPE_%'
GO
