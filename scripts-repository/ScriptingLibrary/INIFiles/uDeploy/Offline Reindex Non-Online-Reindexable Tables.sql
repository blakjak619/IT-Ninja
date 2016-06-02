PRINT REPLICATE('-',140)
PRINT CONVERT(VARCHAR(24),SYSDATETIME(),121) + ' - Script begins'
GO

IF OBJECT_ID('tempdb..#sp_NoWaitMsg') IS NOT NULL
	DROP PROCEDURE #sp_NoWaitMsg
GO

CREATE PROCEDURE
	#sp_NoWaitMsg @NoWaitMessage NVARCHAR(228)
AS
DECLARE @NoWaitMessageWithTimestamp NVARCHAR(255) = CONVERT(NVARCHAR(24),SYSDATETIME(),121) + ' - ' + @NoWaitMessage
RAISERROR(@NoWaitMessageWithTimestamp,0,0) WITH NOWAIT
GO


PRINT REPLICATE('-',140)
EXECUTE #sp_NoWaitMsg N'Reindexing begins'
EXECUTE #sp_NoWaitMsg N'Tables to reindex: 9'

EXECUTE #sp_NoWaitMsg N'[udeploy].[cal_recurring_entry] - Table size is 40.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[cal_recurring_entry] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = OFF);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[cal_recurring_entry] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_def] - Table size is 1.48 MB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ps_prop_def] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = OFF);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_def] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[wf_dispatched_task] - Table size is 1.60 MB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[wf_dispatched_task] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = OFF);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[wf_dispatched_task] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_sa_dialogue] - Table size is 2.86 MB (0.01% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_sa_dialogue] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = OFF);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_sa_dialogue] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[wf_workflow] - Table size is 63.76 MB (0.14% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[wf_workflow] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = OFF);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[wf_workflow] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[cal_entry] - Table size is 138.34 MB (0.31% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[cal_entry] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = OFF);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[cal_entry] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[wf_workflow_trace] - Table size is 3.41 GB (7.82% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[wf_workflow_trace] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = OFF);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[wf_workflow_trace] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_value] - Table size is 6.19 GB (14.19% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ps_prop_value] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = OFF);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_value] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[vc_persistent_record] - Table size is 16.66 GB (38.23% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[vc_persistent_record] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = OFF);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[vc_persistent_record] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'Reindexing complete!'
PRINT REPLICATE('-',140)
EXECUTE #sp_NoWaitMsg N'Update statistics (on all tables) begins';
EXECUTE sp_updatestats;
EXECUTE #sp_NoWaitMsg N'Update statistics complete!';
PRINT REPLICATE('-',140)

GO


DROP PROCEDURE #sp_NoWaitMsg
GO


PRINT CONVERT(VARCHAR(24),SYSDATETIME(),121) + ' - Script complete!'
PRINT REPLICATE('-',140)
GO

 
