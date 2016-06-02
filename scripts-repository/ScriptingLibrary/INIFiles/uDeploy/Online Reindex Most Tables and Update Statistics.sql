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
EXECUTE #sp_NoWaitMsg N'Tables to reindex: 103'

EXECUTE #sp_NoWaitMsg N'[udeploy].[cal_blackout] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[cal_blackout] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[cal_blackout] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_agent_pool] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_agent_pool] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_agent_pool] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_agent_to_pool] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_agent_to_pool] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_agent_to_pool] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_lock] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_lock] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_lock] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_lockable] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_lockable] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_lockable] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_network_relay] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_network_relay] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_network_relay] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_prop_cmp_env_mapping] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_prop_cmp_env_mapping] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_prop_cmp_env_mapping] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_resource_to_role] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_resource_to_role] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_resource_to_role] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_sa_message] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_sa_message] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_sa_message] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_snapshot_config_version] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_snapshot_config_version] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_snapshot_config_version] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_http_prop_info] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ps_http_prop_info] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_http_prop_info] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_sheet_handle] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ps_prop_sheet_handle] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_sheet_handle] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_internal_user] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_internal_user] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_internal_user] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_resource_hierarchy] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_resource_hierarchy] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_resource_hierarchy] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[tsk_approval] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[tsk_approval] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[tsk_approval] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[tsk_approval_to_task] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[tsk_approval_to_task] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[tsk_approval_to_task] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[tsk_task_member_map] - Table size is 0 (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[tsk_task_member_map] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[tsk_task_member_map] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_db_version] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_db_version] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_db_version] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_env_ver_condition] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_env_ver_condition] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_env_ver_condition] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_license] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_license] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_license] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_notification_scheme] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_notification_scheme] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_notification_scheme] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_snapshot_status] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_snapshot_status] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_snapshot_status] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[inv_db_version] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[inv_db_version] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[inv_db_version] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_db_version] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ps_db_version] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_db_version] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_sheet_group] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ps_prop_sheet_group] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_sheet_group] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_authentication_realm] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_authentication_realm] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_authentication_realm] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_authentication_realm_prop] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_authentication_realm_prop] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_authentication_realm_prop] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_authorization_realm] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_authorization_realm] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_authorization_realm] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_authorization_realm_prop] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_authorization_realm_prop] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_authorization_realm_prop] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_db_version] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_db_version] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_db_version] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_group_mapping] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_group_mapping] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_group_mapping] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_resource_type] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_resource_type] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_resource_type] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[vc_commit_lock] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[vc_commit_lock] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[vc_commit_lock] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[vc_db_version] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[vc_db_version] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[vc_db_version] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[wf_db_version] - Table size is 16.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[wf_db_version] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[wf_db_version] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_notification_entry] - Table size is 32.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_notification_entry] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_notification_entry] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_resource_role] - Table size is 32.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_resource_role] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_resource_role] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_group_mapper] - Table size is 32.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_group_mapper] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_group_mapper] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_role] - Table size is 32.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_role] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_role] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_schema] - Table size is 32.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_schema] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_schema] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[tsk_task_definition] - Table size is 32.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[tsk_task_definition] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[tsk_task_definition] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_recent_report] - Table size is 40.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_recent_report] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_recent_report] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_user_preferences] - Table size is 40.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_user_preferences] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_user_preferences] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[cal_recurring_entry_to_cal] - Table size is 56.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[cal_recurring_entry_to_cal] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[cal_recurring_entry_to_cal] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_action] - Table size is 64.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_action] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_action] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_res_group_static] - Table size is 72.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_res_group_static] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_res_group_static] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_status] - Table size is 80.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_status] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_status] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_process_request] - Table size is 80.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[rt_process_request] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_process_request] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[pl_plugin] - Table size is 88.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[pl_plugin] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[pl_plugin] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_res_group_static_to_res] - Table size is 104.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_res_group_static_to_res] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_res_group_static_to_res] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_role_to_action] - Table size is 104.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_role_to_action] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_role_to_action] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_user] - Table size is 120.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_user] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_user] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_dynamic_role_to_action] - Table size is 128.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_dynamic_role_to_action] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_dynamic_role_to_action] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_vfs_repo_rec] - Table size is 136.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_vfs_repo_rec] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_vfs_repo_rec] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_group] - Table size is 144.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_group] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_group] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_comp_ver_int_rec] - Table size is 152.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_comp_ver_int_rec] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_comp_ver_int_rec] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_sheet_def] - Table size is 152.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ps_prop_sheet_def] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_sheet_def] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_resource_condition] - Table size is 184.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_resource_condition] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_resource_condition] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_version_status] - Table size is 192.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_version_status] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_version_status] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_res_group_dynamic] - Table size is 200.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_res_group_dynamic] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_res_group_dynamic] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_agent_data] - Table size is 248.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_agent_data] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_agent_data] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[pl_plugin_command] - Table size is 416.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[pl_plugin_command] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[pl_plugin_command] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_dynamic_role_prop] - Table size is 472.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_dynamic_role_prop] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_dynamic_role_prop] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_user_to_group] - Table size is 512.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_user_to_group] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_user_to_group] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_application] - Table size is 688.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_application] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_application] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[cal_calendar] - Table size is 904.0 KB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[cal_calendar] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[cal_calendar] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_component] - Table size is 1.36 MB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_component] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_component] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[wf_workflow_metadata] - Table size is 1.45 MB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[wf_workflow_metadata] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[wf_workflow_metadata] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_dynamic_role] - Table size is 1.62 MB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_dynamic_role] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_dynamic_role] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_agent] - Table size is 1.73 MB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_agent] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_agent] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_group_role_on_resource] - Table size is 1.76 MB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_group_role_on_resource] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_group_role_on_resource] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[tsk_task] - Table size is 1.77 MB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[tsk_task] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[tsk_task] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_application_to_component] - Table size is 1.79 MB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_application_to_component] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_application_to_component] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_resource] - Table size is 1.98 MB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_resource] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_resource] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[tsk_task_resource_role_map] - Table size is 2.06 MB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[tsk_task_resource_role_map] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[tsk_task_resource_role_map] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_resource] - Table size is 2.10 MB (0.00% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_resource] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_resource] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_snapshot] - Table size is 2.69 MB (0.01% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_snapshot] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_snapshot] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_snapshot_to_version] - Table size is 2.78 MB (0.01% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_snapshot_to_version] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_snapshot_to_version] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_version_selector] - Table size is 2.92 MB (0.01% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[rt_version_selector] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_version_selector] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[inv_env_prop_inventory] - Table size is 4.17 MB (0.01% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[inv_env_prop_inventory] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[inv_env_prop_inventory] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_environment] - Table size is 4.85 MB (0.01% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_environment] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_environment] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[inv_desired_inventory] - Table size is 5.20 MB (0.01% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[inv_desired_inventory] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[inv_desired_inventory] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_deployment_request] - Table size is 5.30 MB (0.01% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[rt_deployment_request] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_deployment_request] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_def_allowed_value] - Table size is 5.52 MB (0.01% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ps_prop_def_allowed_value] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_def_allowed_value] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_user_role_on_resource] - Table size is 6.45 MB (0.01% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_user_role_on_resource] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_user_role_on_resource] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[inv_resource_inventory] - Table size is 14.67 MB (0.03% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[inv_resource_inventory] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[inv_resource_inventory] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_version] - Table size is 33.21 MB (0.07% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_version] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_version] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[rp_app_req_plugin] - Table size is 35.81 MB (0.08% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[rp_app_req_plugin] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[rp_app_req_plugin] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_auth_token] - Table size is 36.66 MB (0.08% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[sec_auth_token] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[sec_auth_token] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_app_proc_req_to_version] - Table size is 37.52 MB (0.08% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[rt_app_proc_req_to_version] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_app_proc_req_to_version] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[vc_commit] - Table size is 42.55 MB (0.10% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[vc_commit] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[vc_commit] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_app_process_request] - Table size is 48.02 MB (0.11% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[rt_app_process_request] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_app_process_request] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_res_grp_cmp_env_mapping] - Table size is 51.89 MB (0.12% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_res_grp_cmp_env_mapping] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_res_grp_cmp_env_mapping] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[vc_latest_version_entry] - Table size is 94.47 MB (0.21% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[vc_latest_version_entry] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[vc_latest_version_entry] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_sheet] - Table size is 95.46 MB (0.21% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ps_prop_sheet] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ps_prop_sheet] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_property_context] - Table size is 108.22 MB (0.24% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[rt_property_context] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_property_context] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_plugin_task_request] - Table size is 213.67 MB (0.48% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_plugin_task_request] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_plugin_task_request] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[cal_entry_to_calendar] - Table size is 324.18 MB (0.73% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[cal_entry_to_calendar] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[cal_entry_to_calendar] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[vc_commit_path_entry] - Table size is 528.41 MB (1.18% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[vc_commit_path_entry] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[vc_commit_path_entry] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_comp_process_request] - Table size is 704.92 MB (1.58% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[rt_comp_process_request] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_comp_process_request] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[inv_resource_config_inventory] - Table size is 1.91 GB (4.38% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[inv_resource_config_inventory] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[inv_resource_config_inventory] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_property_context_group_map] - Table size is 2.84 GB (6.51% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[rt_property_context_group_map] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[rt_property_context_group_map] - Index rebuild complete';

EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_audit_entry] - Table size is 9.99 GB (22.93% of the database); index rebuild begins';
EXECUTE sp_ExecuteSQL N'ALTER INDEX ALL ON [udeploy].[ds_audit_entry] REBUILD WITH (SORT_IN_TEMPDB = ON, ONLINE = ON);'
EXECUTE #sp_NoWaitMsg N'[udeploy].[ds_audit_entry] - Index rebuild complete';

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

 
