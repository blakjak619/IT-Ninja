EXEC sp_configure 'show advanced option', '1'
GO
RECONFIGURE
go
DECLARE @cpu2 int, @mem int, @maxmem INT, @ver nvarchar(128), @DynamicTSQL NVARCHAR(500)

SET @ver = CAST(serverproperty('ProductVersion') AS nvarchar)
SET @ver = SUBSTRING(@ver, 1, CHARINDEX('.', @ver) - 1)
SET @mem = ''

IF ( @ver = '10' )
   SET @DynamicTSQL = 'SELECT @mem2 = physical_memory_in_bytes /1024 /1024 from sys.dm_os_sys_info'
ELSE IF ( @ver >= '11' )
  SET @DynamicTSQL = 'SELECT @mem2 = physical_memory_kb / 1024 from sys.dm_os_sys_info'
ELSE
   SELECT 'Unsupported SQL Server Version'

EXECUTE sp_executesql @DynamicTSQL, N'@mem2 nvarchar(500) OUTPUT',@mem2=@mem OUTPUT
--SELECT @DynamicTSQL

set @maxmem = @mem * .95

IF @mem between 0 and 4096
	EXEC sp_configure 'max server memory', 3072
ELSE IF @mem between 4097 and 8192
	EXEC sp_configure 'max server memory', 6144
--ELSE IF @mem between 8193 and 99999				--modified, since servers have memory > 99999 now  7/10/2012 -mcj
ELSE IF @mem > 8192
	EXEC sp_configure 'max server memory', @maxmem
ELSE
	PRINT 'manually max server memory'

EXEC sp_configure 'show advanced option', '0'
GO
RECONFIGURE
GO
