/*************************************
-- Post installation configuration
-- Sample! For testing purposes only.
*************************************/
USE [master]
GO
SET NOCOUNT ON
--
-- Add additional SQL Server logs
Print 'Add additional SQL Server Logs - 10';
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs', REG_DWORD, 10;
GO

--
-- Enable sp_configure to change advanced settings
EXEC sys.sp_configure N'show advanced options', N'1';
RECONFIGURE WITH OVERRIDE;
GO

--
-- Enable backup compression - Enabled for dev machines
Print 'Enable Backup Compression';
EXEC sys.sp_configure N'backup compression default', N'1';
RECONFIGURE WITH OVERRIDE;
GO

--
-- Enable optimize for ad hoc workloads.
EXEC sys.sp_configure N'optimize for ad hoc workloads', N'1'
RECONFIGURE WITH OVERRIDE
GO

--
-- Set min server memory
Print 'Set min server memory';
EXEC sp_configure 'min server memory', 512;
RECONFIGURE WITH OVERRIDE
GO

--
-- Set max server memory
Print 'Set max server memory';
EXEC sp_configure 'max server memory', 8192;
RECONFIGURE WITH OVERRIDE;
GO

--
-- Disable sp_configure advanced settings
EXEC sys.sp_configure N'show advanced options', N'0';
RECONFIGURE WITH OVERRIDE;
GO

--
-- Set model, master and msdb defaults 
-- Change initial size of the data file to 512MB
Print 'Configure defaults for Model, Master, Tempdb and Msdb'
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modeldev', SIZE = 524288KB );
GO
-- Change initial size of the log file to 256MB
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modellog', SIZE = 262144KB );
GO
-- Autogrowth data file - 128MB
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modeldev', FILEGROWTH = 262144KB );
GO
-- Autogrowth log file - 128MB
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modellog', FILEGROWTH = 131072KB );
GO

-- Change initial size of TempDB database files to 2048MB
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev', SIZE = 262144KB );
GO
-- Change initial size of the log file to 512MB
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'templog', SIZE = 65536KB );
GO

-- Change initial size of master database files to 64MB
ALTER DATABASE [master] MODIFY FILE ( NAME = N'master', SIZE = 65536KB );
GO
-- Change initial size of the log file to 32MB
ALTER DATABASE [master] MODIFY FILE ( NAME = N'mastlog', SIZE = 32768KB );
GO
-- Autogrowth data file - 32MB
ALTER DATABASE [master] MODIFY FILE ( NAME = N'master', FILEGROWTH = 32768KB );
GO
-- Autogrowth log file - 32MB
ALTER DATABASE [master] MODIFY FILE ( NAME = N'mastlog', FILEGROWTH = 32768KB );
GO

-- Change initial size of msdb database files 64MB
ALTER DATABASE [msdb] MODIFY FILE ( NAME = N'MSDBData', SIZE = 131072KB );
GO
-- Change initial size of the log file to 32MB
ALTER DATABASE [msdb] MODIFY FILE ( NAME = N'MSDBLog', SIZE = 65536KB );
GO
-- Autogrowth data file - 32MB
ALTER DATABASE [msdb] MODIFY FILE ( NAME = N'MSDBData', FILEGROWTH = 32768KB );
GO
-- Autogrowth log file - 32MB
ALTER DATABASE [msdb] MODIFY FILE ( NAME = N'MSDBLog', FILEGROWTH = 32768KB );
GO

--
-- Modify number of TempDB's
Print 'Add additional TempDB files'
CREATE TABLE #numprocs (
	[Index] INT,
	[Name] VARCHAR(200),
	Internal_Value VARCHAR(50),
	Character_Value VARCHAR(200)
)
  
DECLARE @BASEPATH VARCHAR(200)
DECLARE @PATH VARCHAR(200)
DECLARE @SQL_SCRIPT VARCHAR(500)
DECLARE @CORES INT
DECLARE @FILECOUNT INT
DECLARE @SIZE INT
DECLARE @GROWTH INT
DECLARE @ISPERCENT INT
  
INSERT INTO #numprocs
	EXEC xp_msver
  
SELECT @CORES = Internal_Value FROM #numprocs WHERE [Index] = 16
PRINT @CORES
  
SET @BASEPATH = (select SUBSTRING(physical_name, 1, CHARINDEX(N'tempdb.mdf', LOWER(physical_name)) - 1) DataFileLocation
					FROM master.sys.master_files
					WHERE database_id = 2 and FILE_ID = 1)

PRINT @BASEPATH
  
SET @FILECOUNT = (SELECT COUNT(*)
					 FROM master.sys.master_files
					 WHERE database_id = 2 AND TYPE_DESC = 'ROWS')
  
SELECT @SIZE = size FROM master.sys.master_files WHERE database_id = 2 AND FILE_ID = 1
SET @SIZE = @SIZE / 128
  
-- 2017-02-13 Aanpassing t.b.v. MB/%
SELECT @GROWTH = CASE is_percent_growth
		WHEN 1 THEN CONVERT(VARCHAR, growth)
		WHEN 0 THEN CONVERT(VARCHAR, growth/128)
		END
FROM master.sys.master_files 
WHERE database_id = 2 
AND FILE_ID = 1

SELECT @ISPERCENT = is_percent_growth 
FROM master.sys.master_files 
WHERE database_id = 2 
AND FILE_ID = 1
  
-- Add number of files based on cores with a maximum of 8 files
IF @CORES > 8 
  SET @CORES = 8
 
WHILE @CORES > @FILECOUNT
	BEGIN
		SET @SQL_SCRIPT = 'ALTER DATABASE tempdb
			ADD FILE
			(
			FILENAME = ''' + @BASEPATH + 'tempdb' + RTRIM(CAST(@CORES as CHAR)) + '.ndf'',
			NAME = tempdev' + RTRIM(CAST(@CORES as CHAR)) + ',
			SIZE = ' + RTRIM(CAST(@SIZE as CHAR)) + 'MB,
			FILEGROWTH = ' + RTRIM(CAST(@GROWTH as CHAR))
		IF @ISPERCENT > 0
			SET @SQL_SCRIPT = @SQL_SCRIPT + '%'
		
		SET @SQL_SCRIPT = @SQL_SCRIPT + ')'
  
	EXEC(@SQL_SCRIPT)
	SET @CORES = @CORES - 1
END;

DROP TABLE #numprocs;
