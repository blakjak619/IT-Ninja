/*  OLTP Servers run this script */
-- set RCSI on for Model System DB
use [model];
alter database [model] set read_committed_snapshot on;

-- Increase the default size of the sql agent job history
USE [msdb]
GO
EXEC msdb.dbo.sp_set_sqlagent_properties 
@jobhistory_max_rows=100000
GO

use master
go
-- Add the service account credentials and make them system admins
if not exists (select * from master.dbo.syslogins where loginname = N'BRIDGEPOINT\sql_agent_dev')
	exec sp_grantlogin N'BRIDGEPOINT\sql_agent_dev'
    exec sp_addsrvrolemember N'BRIDGEPOINT\sql_agent_dev', sysadmin
GO

if not exists (select * from master.dbo.syslogins where loginname = N'BRIDGEPOINT\sql_server_dev')
	exec sp_grantlogin N'BRIDGEPOINT\sql_server_dev'
    exec sp_addsrvrolemember N'BRIDGEPOINT\sql_server_dev', sysadmin
GO

if not exists (select * from master.dbo.syslogins where loginname = N'BRIDGEPOINT\SQL_Level_3')
	exec sp_grantlogin N'BRIDGEPOINT\SQL_Level_3'
    exec sp_addsrvrolemember N'BRIDGEPOINT\SQL_Level_3', sysadmin
GO

-- Turn on Advanced Options
EXEC sp_configure 'show advanced option', '1'
GO
RECONFIGURE
go
-- Set the default fill factor
EXEC sp_configure N'fill factor (%)', N'80'
GO
-- Enable the default trace option
EXEC sp_configure 'default trace enabled', 1;
-- Enable ad hoc work loads to reduce plan cache bloat
EXEC sp_configure 'optimize for ad hoc workloads', 1
GO

RECONFIGURE WITH OVERRIDE
GO
-- Set the DAC to allow remote connections
EXEC sp_configure 'remote admin connections', 1;

-- Enable OLE procedures that are used by the monitoring process
EXEC sp_configure 'Ole Automation Procedures', 1;

-- Turn Advanced Options back off
EXEC sp_configure 'show advanced option', '0'
GO
RECONFIGURE
go

-- Add the DBA - Team operator
USE [msdb]
GO
/****** Object:  Operator [DBA - Team]    Script Date: 05/11/2009 16:40:16 ******/
IF  EXISTS (SELECT name FROM msdb.dbo.sysoperators WHERE name = N'DBA - Team')
EXEC msdb.dbo.sp_delete_operator @name=N'DBA - Team'
GO
/****** Object:  Operator [DBA - Team]    Script Date: 05/11/2009 16:40:08 ******/
EXEC msdb.dbo.sp_add_operator @name=N'DBA - Team', 
		@enabled=1, 
		@weekday_pager_start_time=90000, 
		@weekday_pager_end_time=180000, 
		@saturday_pager_start_time=90000, 
		@saturday_pager_end_time=180000, 
		@sunday_pager_start_time=90000, 
		@sunday_pager_end_time=180000, 
		@pager_days=0, 
		@email_address=N'dba@bridgepointeducation.com', 
		@category_name=N'[Uncategorized]'
GO

-- Add the ECC - Team operator
USE [msdb]
GO
IF  EXISTS (SELECT name FROM msdb.dbo.sysoperators WHERE name = N'ECC - Team')
EXEC msdb.dbo.sp_delete_operator @name=N'ECC - Team'
GO
EXEC msdb.dbo.sp_add_operator @name=N'ECC - Team', 
		@enabled=1, 
		@weekday_pager_start_time=90000, 
		@weekday_pager_end_time=180000, 
		@saturday_pager_start_time=90000, 
		@saturday_pager_end_time=180000, 
		@sunday_pager_start_time=90000, 
		@sunday_pager_end_time=180000, 
		@pager_days=0, 
		@email_address=N'itnoc@bridgepointeducation.com', 
		@category_name=N'[Uncategorized]'
GO

-- Add the non-standard Alerts
IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'Could not allocate space for object'))
EXECUTE msdb.dbo.sp_delete_alert @name = N'Could not allocate space for object' 
BEGIN 
EXECUTE msdb.dbo.sp_add_alert @name = N'Could not allocate space for object', @message_id = 1105, @severity = 0, @enabled = 1, @delay_between_responses = 300, @include_event_description_in = 3, @category_name = N'[Uncategorized]'
EXECUTE msdb.dbo.sp_add_notification @alert_name = N'Could not allocate space for object', @operator_name = N'DBA - Team', @notification_method = 1
END
GO

IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'Log File Full All Databases'))
EXECUTE msdb.dbo.sp_delete_alert @name = N'Log File Full All Databases' 
BEGIN 
EXECUTE msdb.dbo.sp_add_alert @name = N'Log File Full All Databases', @message_id = 9002, @severity = 0, @enabled = 1, @delay_between_responses = 300, @include_event_description_in = 3, @category_name = N'[Uncategorized]'
EXECUTE msdb.dbo.sp_add_notification @alert_name = N'Log File Full All Databases', @operator_name = N'DBA - Team', @notification_method = 1
END
GO

IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'SQL Server Shutdown'))
EXECUTE msdb.dbo.sp_delete_alert @name = N'SQL Server Shutdown' 
BEGIN 
EXECUTE msdb.dbo.sp_add_alert @name = N'SQL Server Shutdown', @message_id = 17147, @severity = 0, @enabled = 1, @delay_between_responses = 60, @include_event_description_in = 3, @category_name = N'[Uncategorized]'
EXECUTE msdb.dbo.sp_add_notification @alert_name = N'SQL Server Shutdown', @operator_name = N'DBA - Team', @notification_method = 1
END
GO

IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'SQL Server stop request'))
EXECUTE msdb.dbo.sp_delete_alert @name = N'SQL Server stop request' 
BEGIN 
EXECUTE msdb.dbo.sp_add_alert @name = N'SQL Server stop request', @message_id = 17148, @severity = 0, @enabled = 1, @delay_between_responses = 60, @include_event_description_in = 3, @category_name = N'[Uncategorized]'
EXECUTE msdb.dbo.sp_add_notification @alert_name = N'SQL Server stop request', @operator_name = N'DBA - Team', @notification_method = 1
END
GO

IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'Stack Dump'))
EXECUTE msdb.dbo.sp_delete_alert @name = N'Stack Dump' 
BEGIN 
EXECUTE msdb.dbo.sp_add_alert @name = N'Stack Dump', @message_id = 565, @severity = 0, @enabled = 1, @delay_between_responses = 60, @include_event_description_in = 5, @category_name = N'[Uncategorized]'
EXECUTE msdb.dbo.sp_add_notification @alert_name = N'Stack Dump', @operator_name = N'DBA - Team', @notification_method = 1
END
GO

IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'SQL Scheduler Hung'))
EXECUTE msdb.dbo.sp_delete_alert @name = N'SQL Scheduler Hung' 
BEGIN 
EXECUTE msdb.dbo.sp_add_alert @name = N'SQL Scheduler Hung', @message_id = 17883, @severity = 0, @enabled = 1, @delay_between_responses = 60, @include_event_description_in = 5, @category_name = N'[Uncategorized]'
EXECUTE msdb.dbo.sp_add_notification @alert_name = N'SQL Scheduler Hung', @operator_name = N'DBA - Team', @notification_method = 1
END
GO

IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'019 - Nonconfigurable DB Engine limit exceeded. Current batch process terminated'))
EXECUTE msdb.dbo.sp_delete_alert @name = N'019 - Nonconfigurable DB Engine limit exceeded. Current batch process terminated' 
BEGIN
EXEC msdb.dbo.sp_add_alert @name=N'019 - Nonconfigurable DB Engine limit exceeded. Current batch process terminated', 
		@message_id=0, 
		@severity=19, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@job_id=N'00000000-0000-0000-0000-000000000000'
EXEC msdb.dbo.sp_add_notification @alert_name=N'019 - Nonconfigurable DB Engine limit exceeded. Current batch process terminated', @operator_name=N'DBA - Team', @notification_method = 1
END
GO

IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'020 - Statement has encountered a problem. It is unlikely DB has been damaged. Chk Error Log'))
EXECUTE msdb.dbo.sp_delete_alert @name = N'020 - Statement has encountered a problem. It is unlikely DB has been damaged. Chk Error Log' 
BEGIN
EXEC msdb.dbo.sp_add_alert @name=N'020 - Statement has encountered a problem. It is unlikely DB has been damaged. Chk Error Log', 
		@message_id=0, 
		@severity=20, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@job_id=N'00000000-0000-0000-0000-000000000000'
EXEC msdb.dbo.sp_add_notification @alert_name=N'020 - Statement has encountered a problem. It is unlikely DB has been damaged. Chk Error Log', @operator_name=N'DBA - Team', @notification_method = 1
END
GO

IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'021 - Problem encountered that affects all tasks in the DB, it is unlikely that the DB has been damaged'))
EXECUTE msdb.dbo.sp_delete_alert @name = N'021 - Problem encountered that affects all tasks in the DB, it is unlikely that the DB has been damaged' 
BEGIN
EXEC msdb.dbo.sp_add_alert @name=N'021 - Problem encountered that affects all tasks in the DB, it is unlikely that the DB has been damaged', 
		@message_id=0, 
		@severity=21, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@job_id=N'00000000-0000-0000-0000-000000000000'
EXEC msdb.dbo.sp_add_notification @alert_name=N'021 - Problem encountered that affects all tasks in the DB, it is unlikely that the DB has been damaged', @operator_name=N'DBA - Team', @notification_method = 1
END
GO

IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'022 - Table or index specified in the message has been damaged by a software or hardware problem'))
EXECUTE msdb.dbo.sp_delete_alert @name = N'022 - Table or index specified in the message has been damaged by a software or hardware problem' 
BEGIN
EXEC msdb.dbo.sp_add_alert @name=N'022 - Table or index specified in the message has been damaged by a software or hardware problem', 
		@message_id=0, 
		@severity=22, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@job_id=N'00000000-0000-0000-0000-000000000000'
EXEC msdb.dbo.sp_add_notification @alert_name=N'022 - Table or index specified in the message has been damaged by a software or hardware problem', @operator_name=N'DBA - Team', @notification_method = 1
END
GO

IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'023 - Integrity of the entire DB is in question because of a hardware or software problem'))
EXECUTE msdb.dbo.sp_delete_alert @name = N'023 - Integrity of the entire DB is in question because of a hardware or software problem' 
BEGIN
EXEC msdb.dbo.sp_add_alert @name=N'023 - Integrity of the entire DB is in question because of a hardware or software problem', 
		@message_id=0, 
		@severity=23, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@job_id=N'00000000-0000-0000-0000-000000000000'
EXEC msdb.dbo.sp_add_notification @alert_name=N'023 - Integrity of the entire DB is in question because of a hardware or software problem', @operator_name=N'DBA - Team', @notification_method = 1
END
GO

IF (EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'024 - Fatal Hardware Error'))
EXECUTE msdb.dbo.sp_delete_alert @name = N'024 - Fatal Hardware Error' 
BEGIN
EXEC msdb.dbo.sp_add_alert @name=N'024 - Fatal Hardware Error', 
		@message_id=0, 
		@severity=24, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1, 
		@job_id=N'00000000-0000-0000-0000-000000000000'
EXEC msdb.dbo.sp_add_notification @alert_name=N'024 - Fatal Hardware Error', @operator_name=N'DBA - Team', @notification_method = 1
END
GO

IF  EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name = N'825 - Read-Retry Required')
EXEC msdb.dbo.sp_delete_alert @name=N'825 - Read-Retry Required'
BEGIN
EXEC msdb.dbo.sp_add_alert @name = N'825 - Read-Retry Required', 
    @message_id = 825,
    @severity = 0,
    @enabled = 1,
    @delay_between_responses = 0,
    @include_event_description_in = 1;

EXEC msdb.dbo.sp_add_notification @alert_name=N'825 - Read-Retry Required', @operator_name=N'DBA - Team', @notification_method = 1
END

-------------------------------------------------------------
--  Enable Database Mail
--
--  Database mail is disabled by default.
--  This script enables the database mail
--  extended stored procedures.
-------------------------------------------------------------

exec sp_configure 'show advanced options', 1;
GO
RECONFIGURE;
GO
exec sp_configure 'Database Mail XPs', 1;
GO
RECONFIGURE
GO

-------------------------------------------------------------
--  Database Mail Simple Configuration Template.
--
--  This template creates a Database Mail profile, an SMTP account and 
--  associates the account to the profile.
--  The template does not grant access to the new profile for
--  any database principals.  Use msdb.dbo.sysmail_add_principalprofile
--  to grant access to the new profile for users who are not
--  members of sysadmin.
-------------------------------------------------------------

DECLARE @profile_name sysname,
        @account_name sysname,
        @SMTP_servername sysname,
        @email_address NVARCHAR(128),
        @replyto_address NVARCHAR(128),
        @display_name NVARCHAR(128);

-- Profile name. Replace with the name for your profile
        SET @profile_name = 'DBA';

-- Account information. Replace with the information for your account.
		SET @account_name = 'DBA';
        SET @SMTP_servername = 'mail-tools.bridgepoint.local';
        SET @email_address = 'DBA_Mail@bridgepointeducation.com';
        SET @replyto_address = 'dba@bridgepointeducation.com';
        SET @display_name = (select @@SERVERNAME);

-- Verify the specified account and profile do not already exist.
IF EXISTS (SELECT * FROM msdb.dbo.sysmail_profile WHERE name = @profile_name)
BEGIN
  RAISERROR('The specified Database Mail profile (Job Notify) already exists.', 16, 1);
  GOTO done;
END;

IF EXISTS (SELECT * FROM msdb.dbo.sysmail_account WHERE name = @account_name )
BEGIN
 RAISERROR('The specified Database Mail account (Outgoing Mail) already exists.', 16, 1) ;
 GOTO done;
END;

-- Start a transaction before adding the account and the profile
BEGIN TRANSACTION ;

DECLARE @rv INT;

-- Add the account
EXECUTE @rv=msdb.dbo.sysmail_add_account_sp
    @account_name = @account_name,
    @email_address = @email_address,
    @replyto_address = @replyto_address,
    @display_name = @display_name,
    @mailserver_name = @SMTP_servername;

IF @rv<>0
BEGIN
    RAISERROR('Failed to create the specified Database Mail account (Outgoing Mail).', 16, 1) ;
    GOTO done;
END

-- Add the profile
EXECUTE @rv=msdb.dbo.sysmail_add_profile_sp
    @profile_name = @profile_name ;

IF @rv<>0
BEGIN
    RAISERROR('Failed to create the specified Database Mail profile (Job Notify).', 16, 1);
                ROLLBACK TRANSACTION;
    GOTO done;
END;

-- Associate the account with the profile.
EXECUTE @rv=msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name = @profile_name,
    @account_name = @account_name,
    @sequence_number = 1 ;

IF @rv<>0
BEGIN
    RAISERROR('Failed to associate the speficied profile with the specified account (Outgoing Mail).', 16, 1) ;
                ROLLBACK TRANSACTION;
    GOTO done;
END;

COMMIT TRANSACTION;

done:

EXEC msdb.dbo.sysmail_delete_principalprofile_sp @principal_name=N'guest', @profile_name=N'DBA'
EXEC msdb.dbo.sysmail_add_principalprofile_sp @principal_name=N'guest', @profile_name=N'DBA', @is_default=1
go