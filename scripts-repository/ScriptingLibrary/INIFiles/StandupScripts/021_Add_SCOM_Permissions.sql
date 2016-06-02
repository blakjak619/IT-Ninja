/**
	For new servers we are monitoring with SCOM 2012 and using the security model of least privileges.  Per the SCOM 
	Management Pack (MP) documentaion this is all that's needed.
*/
USE master
IF NOT EXISTS ( SELECT  *
                FROM    sys.server_principals AS sp
                WHERE   sp.name = 'BRIDGEPOINT\SVC_SCOMSQL' )
    BEGIN
        CREATE LOGIN [BRIDGEPOINT\SVC_SCOMSQL] FROM WINDOWS
    END

GRANT VIEW SERVER STATE TO [BRIDGEPOINT\SVC_SCOMSQL]

-- these two only work if it's SQL 2012
DECLARE @version TINYINT
SELECT  @version = LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR), 2)
SELECT  @version

IF ( @version >= 11 )
    BEGIN
        GRANT VIEW ANY DATABASE TO [BRIDGEPOINT\SVC_SCOMSQL]    -- This is also inherited with "public" server role by default
        GRANT VIEW ANY DEFINITION TO [BRIDGEPOINT\SVC_SCOMSQL]
    END 

EXEC sys.sp_MSforeachdb
    'USE [?]
    -- Check if the database is writable
    IF DATABASEPROPERTYEX(''?'', ''Updateability'') = ''READ_WRITE''
        BEGIN
            IF NOT EXISTS ( SELECT  *
                            FROM    sys.database_principals AS dp
                            WHERE   dp.name = ''BRIDGEPOINT\SVC_SCOMSQL'' )
                BEGIN
                    CREATE USER [BRIDGEPOINT\SVC_SCOMSQL] FROM LOGIN [BRIDGEPOINT\SVC_SCOMSQL]
                END
        END
'
USE msdb
EXEC sp_addrolemember
    @rolename = 'SQLAgentReaderRole'
    , @membername = 'BRIDGEPOINT\SVC_SCOMSQL'
EXEC sp_addrolemember
    @rolename = 'PolicyAdministratorRole'
    , @membername = 'BRIDGEPOINT\SVC_SCOMSQL'
------------------------------------------------------------------------------------------------
-- You can also run the ForeachDB as a job or job step to re-grant SCOM service account access 
-- to restored databases
------------------------------------------------------------------------------------------------

GO
