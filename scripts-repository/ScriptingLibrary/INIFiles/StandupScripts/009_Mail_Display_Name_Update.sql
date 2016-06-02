
 -- Execute to change the Display Name from DBA to the actual servername for better email alerting
 -- Makes the modification, then generates a test email to the group
 -- Verify the profile name before executing
 -- Warren Allred - July 2011  
  
  UPDATE msdb.dbo.sysmail_account
  SET display_name = (select @@SERVERNAME)
  WHERE name = 'DBA'
  
EXEC msdb.dbo.sp_send_dbmail
@recipients=N'dba@bridgepointeducation.com',
@body='Updated the display_name column in the msdb.dbo.sysmail_account table
to the HostName in order to quickly identify which server our alerts are coming from.', 
@subject ='Test Email - Server display_name Update',
@profile_name ='DBA' --VERIFY SO AS NOT TO OVERWRITE/HAVE SCRIPT FAILURE IF MULTIPLE PROFILES EXIST

GO
