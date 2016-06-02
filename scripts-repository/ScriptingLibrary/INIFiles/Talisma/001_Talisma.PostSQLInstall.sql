
if not exists (select * from master.dbo.syslogins where loginname = N'BRIDGEPOINT\@@@crm_svc_acct@@@')
	exec sp_grantlogin N'BRIDGEPOINT\@@@crm_svc_acct@@@'
    exec sp_addsrvrolemember N'BRIDGEPOINT\@@@crm_svc_acct@@@', sysadmin
GO

if not exists (select * from master.dbo.syslogins where loginname = N'BRIDGEPOINT\tgreulich')
	exec sp_grantlogin N'BRIDGEPOINT\tgreulich'
    exec sp_addsrvrolemember N'BRIDGEPOINT\tgreulich', sysadmin
GO

sp_configure 'show advanced options', 1
reconfigure
go

sp_configure 'Ad Hoc Distributed Queries', 1
reconfigure
go

sp_configure 'Ole Automation Procedures', 1
reconfigure
go

sp_configure 'xp_cmdshell', 1
reconfigure
go

sp_configure 'Agent XPs', 1;
GO
RECONFIGURE
