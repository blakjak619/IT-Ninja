USE master
GO
IF NOT EXISTS(SELECT * 
              FROM sys.databases AS d
			  WHERE d.name = 'SQLAdmin')
BEGIN
	CREATE DATABASE [SQLAdmin]
	ALTER DATABASE [SQLAdmin] MODIFY FILE ( NAME = N'SQLAdmin', SIZE = 1048576KB , FILEGROWTH = 524288KB )
	ALTER DATABASE [SQLAdmin] MODIFY FILE ( NAME = N'SQLAdmin_log', SIZE = 524288KB , FILEGROWTH = 524288KB )
	ALTER DATABASE [SQLAdmin] SET RECOVERY SIMPLE WITH NO_WAIT
END	
GO
USE [SQLAdmin]
GO
EXEC dbo.sp_changedbowner @loginame = N'sa', @map = false
GO
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS(SELECT * 
              FROM sys.objects AS o 
			  WHERE o.name = 'Admin_Index_Maintenance_History')
BEGIN 
CREATE TABLE [dbo].[Admin_Index_Maintenance_History](
	[InsertDate] Datetime NULL,
	[SchemaName] [nvarchar](128) NULL,
	[TableName] [nvarchar](128) NULL,
	[HasLOBs] [tinyint] NULL,
	[ObjectID] [int] NOT NULL,
	[IndexID] [int] NOT NULL,
	[PartitionNumber] [int] NOT NULL,
	[AvgFragPercent] [tinyint] NOT NULL,
	[IndexName] [nvarchar](128) NULL,
	[IndexTypeDesc] [nvarchar](60) NOT NULL
) ON [PRIMARY]
    END
GO

