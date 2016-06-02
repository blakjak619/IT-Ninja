--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Create Temporary Sproc for Output Messages
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
IF OBJECT_ID('tempdb..#sp_msg') IS NOT NULL
    BEGIN
	DECLARE @SQLScript NVARCHAR(128) = 'DROP PROCEDURE #sp_msg;'
	EXECUTE sp_executesql @SQLScript
    END
go--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
CREATE PROCEDURE
	#sp_msg
		@NoWaitMessage	VARCHAR(2000)
	 ,	@AddTimestamp	BIT = 1
AS
    BEGIN
	IF @AddTimestamp = 1
		SET @NoWaitMessage = CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - ' + @NoWaitMessage

	RAISERROR(@NoWaitMessage,0,0) WITH NOWAIT
    END
GO--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

SET NOCOUNT ON
GO

EXECUTE #sp_msg 'Script begins.';
PRINT ''

--------------------------------------------------------------------------------------------------------

DECLARE
	@LinkedServer_Name			SYSNAME
 ,	@LinkedServer_SQLServerInstance		SYSNAME
 ,	@LinkedServer_DefaultDatabase		SYSNAME
 ,	@LinkedServer_LinkProvider		SYSNAME
 ,	@LinkedServer_LinkProduct		SYSNAME
 ,	@LinkedServer_Auth_UseNT		VARCHAR(5) -- (either 'TRUE' or 'FALSE')
 ,	@LinkedServer_Auth_LocalLogin		VARCHAR(30)
 ,	@LinkedServer_Auth_LinkedLogin		VARCHAR(30)
 ,	@LinkedServer_Auth_LinkedLoginPwd	VARCHAR(128)
;

SELECT
	@LinkedServer_Name			= N'SQLINV'
 ,	@LinkedServer_SQLServerInstance		= N'DBA01.BRIDGEPOINT.local'
 ,	@LinkedServer_DefaultDatabase		= N'CentralInventory'
 ,	@LinkedServer_LinkProvider		= N'SQLNCLI'
 ,	@LinkedServer_LinkProduct		= N'SQLServer'
 ,	@LinkedServer_Auth_UseNT		= 'FALSE'
 ,	@LinkedServer_Auth_LocalLogin		= NULL
 ,	@LinkedServer_Auth_LinkedLogin		= 'svc_SQLInventoryCheckIn'
 ,	@LinkedServer_Auth_LinkedLoginPwd	= '*invent0ry^|CHECK-IN'
;

---------------------------------------------------------------------------------------------------------

IF EXISTS
	(
	SELECT	*
	FROM	sys.servers s
	WHERE	s.name = @LinkedServer_Name
	 AND	s.is_linked = 1
	)
    BEGIN
	DECLARE @SQLScript NVARCHAR(MAX) = 'EXECUTE master.dbo.sp_dropserver @server=N''' + @LinkedServer_Name + ''', @droplogins=''droplogins'';'
	--PRINT @SQLScript
	EXECUTE sp_executesql @SQLScript

	EXECUTE #sp_msg 'Dropped existing linked server ("SQLINV").';
    END


EXECUTE
	dbo.sp_AddLinkedServer
		@server		= @LinkedServer_Name
	 ,	@srvproduct	= @LinkedServer_LinkProduct
	 ,	@provider	= @LinkedServer_LinkProvider
	 ,	@datasrc	= @LinkedServer_SQLServerInstance
	 ,	@catalog	= @LinkedServer_DefaultDatabase
;

EXECUTE #sp_msg 'Created linked server ("SQLINV").';

EXECUTE
	dbo.sp_ServerOption
		@server		= @LinkedServer_Name
	 ,	@optname	= N'rpc'
	 ,	@optvalue	= N'true'
;

EXECUTE
	dbo.sp_ServerOption
		@server		= @LinkedServer_Name
	 ,	@optname	= N'rpc out'
	 ,	@optvalue	= N'true'
;

EXECUTE #sp_msg 'Granted "RPC" and "RPC Out" for this linked server.';


EXECUTE
	dbo.sp_AddLinkedSrvLogin
		@rmtsrvname =	@LinkedServer_Name
	 ,	@useself =	@LinkedServer_Auth_UseNT
	 ,	@locallogin =	@LinkedServer_Auth_LocalLogin
	 ,	@rmtuser =	@LinkedServer_Auth_LinkedLogin
	 ,	@rmtpassword =	@LinkedServer_Auth_LinkedLoginPwd

GO
EXECUTE #sp_msg 'Added SQL login "svc_SQLInventoryCheckIn" as the default login for this linked server, regardless of who uses it.';


USE msdb
go

DECLARE @tb_ExtendedProperty TABLE
	(	ExtendedPropertyName SYSNAME	)
;

INSERT INTO
	@tb_ExtendedProperty
VALUES	(	'Bridgepoint_EnvironmentCode'	)
 ,	(	'Bridgepoint_EcosystemName'	)
 ,	(	'Bridgepoint_Notes'		)
;

DECLARE @SQLScript NVARCHAR(MAX) = ''
 ,	@CRLF NCHAR(2) = CHAR(13) + CHAR(10)
;

SELECT	@SQLScript += 'EXECUTE msdb.sys.sp_AddExtendedProperty ''' + ExtendedPropertyName + ''';'  + @CRLF
FROM	@tb_ExtendedProperty ep
WHERE NOT EXISTS
	(
	SELECT	1
	FROM	msdb.sys.extended_properties sep
	WHERE	sep.name = ep.ExtendedPropertyName
	)

EXECUTE	sp_executesql @SQLScript
go

EXECUTE #sp_msg 'Added extended properties in [msdb].';
--PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Added extended properties in [msdb].';
go
USE msdb
go

IF NOT EXISTS
	(
	SELECT	1
	FROM	sys.procedures p
	WHERE	p.[object_id] = OBJECT_ID('dbo.SQLInventoryCheckIn_Insert')
	)
    BEGIN
	EXECUTE	sp_executesql N'CREATE PROCEDURE dbo.SQLInventoryCheckIn_Insert AS SELECT ''Hello, world!'' AS Dummy;'
    END
GO

/*---------------------------------------------------------------------------------------------------
The purpose of this stored procedure for a SQL Server instance to execute a (weekly?) SQL Inventory-
related check-in with a few details about the server

Change Log:
2015-01-05	DJS creates procedure
2015-02-18	DJS adds InstanceNewFlag as input parameter; accommodates changes to table in 
		CentralInventory
2015-02-27	DJS adds context info; needs ot get the #$%! out of the office
2015-03-02	DJS changes to use extended properties and to run from [msdb] instead of [SQLAdmin]
---------------------------------------------------------------------------------------------------*/

ALTER PROCEDURE
	dbo.SQLInventoryCheckIn_Insert

AS

SET NOCOUNT ON

    BEGIN TRY

	DECLARE
		@InstanceName		VARCHAR(144)		-- server name max is 15, then 1 for "\", then up to 128 for instance name
	 ,	@PhysicalMachineName	VARCHAR(15)
	 ,	@DomainName		VARCHAR(63)
	 ,	@ContextInfo		VARBINARY(128)
	 ,	@EnvironmentCode	VARCHAR(10)
	 ,	@EcosystemName		VARCHAR(128)
	 ,	@InstanceNotes		VARCHAR(1000)
	;

	SELECT
		@InstanceName		= CONVERT(VARCHAR(144),SERVERPROPERTY('ServerName'))	-- yes i did this on purpose
	 ,	@PhysicalMachineName	= CONVERT(VARCHAR(15),SERVERPROPERTY('ComputerNamePhysicalNetBIOS'))
	 ,	@DomainName		= DEFAULT_DOMAIN()
	 ,	@ContextInfo		= CONTEXT_INFO()
	;


	/*
	SELECT
		@EnvironmentCode = p.Bridgepoint_EnvironmentCode
	 ,	@EcosystemName	 = p.Bridgepoint_EcosystemName
	 ,	@InstanceNotes	 = p.Bridgepoint_Notes
	FROM
		(
		SELECT
			ExtendedPropertyName = CONVERT(VARCHAR(128),sep.name)
		 ,	ExtendedPropertyValue = CONVERT(VARCHAR(1000),sep.value)
		FROM
			msdb.sys.extended_properties sep
		) x
	 PIVOT	(	MAX(x.ExtendedPropertyValue)
		 FOR	x.ExtendedPropertyName
		  IN 	(	[Bridgepoint_EnvironmentCode]
			 ,	[Bridgepoint_EcosystemName]
			 ,	[Bridgepoint_Notes]
			)
		) p 
	;
	*/
	
	SELECT	@EnvironmentCode = CONVERT(VARCHAR(10),sep.value)
	FROM	msdb.sys.extended_properties sep
	WHERE	sep.name = 'Bridgepoint_EnvironmentCode';


	SELECT	@EcosystemName = CONVERT(VARCHAR(128),sep.value)
	FROM	msdb.sys.extended_properties sep
	WHERE	sep.name = 'Bridgepoint_EcosystemName';


	SELECT	@InstanceNotes = CONVERT(VARCHAR(1000),sep.value)
	FROM	msdb.sys.extended_properties sep
	WHERE	sep.name = 'Bridgepoint_Notes';


	EXECUTE
		SQLINV.CentralInventory.inv.prc_SQLInventoryCheckIn_Insert
			@InstanceName		= @InstanceName
		 ,	@DomainName		= @DomainName
		 ,	@PhysicalMachineName	= @PhysicalMachineName
		 ,	@ContextInfo		= @ContextInfo
		 ,	@EnvironmentCode	= @EnvironmentCode
		 ,	@EcosystemName		= @EcosystemName
		 ,	@InstanceNotes		= @InstanceNotes
	;

     END TRY

     BEGIN CATCH
	
	DECLARE
		@ErrorNumber	  INT		 = ERROR_NUMBER()
	 ,	@ErrorLine	  INT		 = ERROR_LINE()
	 ,	@ErrorSeverity	  INT		 = ERROR_SEVERITY()
	 ,	@ErrorMessage	  NVARCHAR(255)  = ERROR_MESSAGE()
	 ,	@FullErrorMessage NVARCHAR(1000)
	
	SET @FullErrorMessage =
		'Error ' + CAST(@ErrorNumber AS NVARCHAR)
	   +  ', Line ' + CAST(@ErrorLine AS NVARCHAR)
	   + ': ' + @ErrorMessage
	
	RAISERROR(@FullErrorMessage,@ErrorSeverity,1)

    END CATCH
GO

EXECUTE #sp_msg 'Created/altered stored procedure "dbo.SQLInventoryCheckIn_Insert" in [msdb].'
go
USE [msdb]
GO

IF EXISTS
	(
	SELECT	1
	FROM	dbo.sysjobs j
	WHERE	j.name = N'Admin_DBA_SQLInventoryCheckIn'
	)
    BEGIN
	EXEC dbo.sp_delete_job @job_name=N'Admin_DBA_SQLInventoryCheckIn';
	
	PRINT CONVERT(VARCHAR(23),SYSDATETIME(),121) + ' - Dropped existing SQL Agent job "Admin_DBA_SQLInventoryCheckIn".';
    END
 go

DECLARE @jobId BINARY(16)
EXEC msdb.dbo.sp_add_job @job_name=N'Admin_DBA_SQLInventoryCheckIn', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
--select @jobId
GO

DECLARE @ServerName SYSNAME = CONVERT(SYSNAME,SERVERPROPERTY('ServerName'))
EXEC msdb.dbo.sp_add_jobserver @job_name=N'Admin_DBA_SQLInventoryCheckIn', @server_name = @ServerName
GO

EXEC msdb.dbo.sp_add_jobstep @job_name=N'Admin_DBA_SQLInventoryCheckIn', @step_name=N'Check-In for SQL Inventory', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
SET CONTEXT_INFO 0x02
;

EXECUTE
	dbo.SQLInventoryCheckIn_Insert
;', 
		@database_name=N'msdb', 
		@flags=0
GO


EXEC msdb.dbo.sp_update_job @job_name=N'Admin_DBA_SQLInventoryCheckIn', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'', 
		@notify_netsend_operator_name=N'', 
		@notify_page_operator_name=N''
GO

EXECUTE #sp_msg 'Created SQL Agent job "Admin_DBA_SQLInventoryCheckIn".'
go

DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'Admin_DBA_SQLInventoryCheckIn', @name=N'Every Monday Morning at 5am', 
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=2, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20150108, 
		@active_end_date=99991231, 
		@active_start_time=50000, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
--select @schedule_id
GO

EXECUTE #sp_msg 'Scheduled "Admin_DBA_SQLInventoryCheckIn" to run once weekly (Mondays at 5:00am).'
go

DECLARE @schedule_id int
EXEC msdb.dbo.sp_add_jobschedule @job_name=N'Admin_DBA_SQLInventoryCheckIn', @name=N'On SQL Agent Startup', 
		@enabled=1, 
		@freq_type=64, 
		@freq_interval=1, 
		@freq_subday_type=0, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20150217, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, @schedule_id = @schedule_id OUTPUT
--select @schedule_id
GO

EXECUTE #sp_msg 'Scheduled "Admin_DBA_SQLInventoryCheckIn" to run whenever the SQL Agent service starts up.'
go

EXECUTE dbo.sp_start_job
		@job_name = 'Admin_DBA_SQLInventoryCheckIn'
	 ,	@output_flag = 0
;
EXECUTE #sp_msg 'Manually kicked off job "Admin_DBA_SQLInventoryCheckIn".'
GO


SET CONTEXT_INFO 0x01
;

EXECUTE
	msdb.dbo.SQLInventoryCheckIn_Insert
;
go

EXECUTE #sp_msg 'Executed stored procedure "adm.prc_SQLInventoryCheckIn_Insert", indicaing "new installation".'
go
PRINT ''
EXECUTE #sp_msg 'Script Complete!'
go

