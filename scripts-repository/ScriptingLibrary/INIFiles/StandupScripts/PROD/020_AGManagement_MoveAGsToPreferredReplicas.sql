USE master
GO
IF EXISTS ( SELECT  *
            FROM    sys.procedures AS p
            WHERE   p.name = 'BPE_AGManagement_MoveAGsToPreferredReplicas' )
    DROP PROCEDURE BPE_AGManagement_MoveAGsToPreferredReplicas    
GO

CREATE PROCEDURE dbo.BPE_AGManagement_MoveAGsToPreferredReplicas ( @AGName VARCHAR(100) = NULL )
AS 
/***********************************************************************************************
    Created:    2014-09-05
    Author:     Chris Stewart

    Purpose:    The intent of this proc is to move AGs back to their preferred node based on the 
                "backup_priority" field in the AG configuration, which we don't use for anything
                else. This process will generally need to run on every server since the AG 
                failover is a "pull" process - i.e. you need to be on the server to which you 
                want to move the primary replica.
***********************************************************************************************/
------------------------------------------------------------------------------------------------
-- Declare variables
------------------------------------------------------------------------------------------------
DECLARE @CurrentRole VARCHAR(20)
  , @PreferredReplica VARCHAR(20)
  , @SQL VARCHAR(1000) = ''

------------------------------------------------------------------------------------------------
-- Assign default value to input parameters
------------------------------------------------------------------------------------------------
SELECT  @AGName = ISNULL(@AGName, '%')

------------------------------------------------------------------------------------------------
-- Get the current primary replica and the preferred replica for each AG on this node
------------------------------------------------------------------------------------------------
DECLARE AGCur CURSOR LOCAL
FOR
SELECT  ag.name
      , fbgapn.PreferredReplicaName
      , dhars.role_desc
FROM    sys.availability_groups AS ag
        INNER JOIN sys.availability_replicas AS ar
            ON ar.group_id = ag.group_id
        INNER JOIN sys.dm_hadr_availability_replica_states AS dhars
            ON dhars.group_id = ar.group_id
               AND dhars.replica_id = ar.replica_id
        CROSS APPLY dbo.fn_BPE_GetAGPreferredReplica(ag.name) AS fbgapn
WHERE   ar.replica_server_name = @@SERVERNAME
        AND ag.name LIKE @AGName 

OPEN AGCur

WHILE 1 = 1
    BEGIN
        FETCH AGCur INTO @AGName, @PreferredReplica, @CurrentRole
        IF @@FETCH_STATUS <> 0
            BREAK

        ------------------------------------------------------------------------------------------------
        -- If we're on the preferred server but the primary replica is not this server, failover to this 
        -- server.
        ------------------------------------------------------------------------------------------------
        IF ( @PreferredReplica = @@SERVERNAME )
            AND ( @CurrentRole <> 'PRIMARY' )
            BEGIN
                SELECT  @SQL = '-- Failing over ' + @AGName + CHAR(13) + CHAR(10) + 'ALTER AVAILABILITY GROUP '
                        + @AGName + ' FAILOVER'
                --PRINT @SQL
                EXEC (@SQL)
            END
    END
GO
