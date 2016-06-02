USE [msdb]
GO

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'admin_DBA_MoveAGsToPreferredReplicas')
EXEC msdb.dbo.sp_delete_job @job_name=N'admin_DBA_MoveAGsToPreferredReplicas'
GO

DECLARE @jobId BINARY(16)
EXEC  msdb.dbo.sp_add_job @job_name=N'admin_DBA_MoveAGsToPreferredReplicas', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@description=N'SME: Chris Stewart

This job is run on an ad-hoc basis to reset AGs to their preferred replica, generally after patching or after recovering a failed node.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBA - Team', @job_id = @jobId OUTPUT
USE [msdb]
GO

EXEC msdb.dbo.sp_add_jobserver @job_name = 'admin_DBA_MoveAGsToPreferredReplicas', @server_name = N'(local)'
GO

EXEC msdb.dbo.sp_add_jobstep @job_name=N'admin_DBA_MoveAGsToPreferredReplicas', @step_name=N'MoveAGsToPreferredReplicas', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC BPE_AGManagement_MoveAGsToPreferredReplicas
', 
		@database_name=N'master', 
		@flags=0
GO
USE [msdb]
GO
EXEC msdb.dbo.sp_update_job @job_name=N'admin_DBA_MoveAGsToPreferredReplicas', 
		@enabled=1, 
		@start_step_id=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=2, 
		@notify_level_page=2, 
		@delete_level=0, 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'DBA - Team', 
		@notify_netsend_operator_name=N'', 
		@notify_page_operator_name=N''
GO
