DECLARE @MaxDays_Since_Last_Full_Backup INT
DECLARE @MaxDays_Since_Last_Diff_Backup INT
DECLARE @MaxDays_Since_Last_Log_Backup INT


DECLARE @LAST_FULL_BACKUP_LIST TABLE
(
	Database_Name							VARCHAR(100),
	Last_Full_Backup_Finish_DateTime		DATETIME,
	Backup_Type								VARCHAR(1) DEFAULT 'D',
	FullBackup_SetID						INT,
	Full_Backup_Path						VARCHAR(100)
)

DECLARE @LAST_DIFF_BACKUP_LIST TABLE
(
	Database_Name							VARCHAR(100),
	Last_Diff_Backup_Finish_DateTime		DATETIME,
	Backup_Type								VARCHAR(1) DEFAULT 'I',
	DiffBackup_SetID						INT,
	Diff_Backup_Path						VARCHAR(100)
)

DECLARE @LAST_LOG_BACKUP_LIST TABLE
(
	Database_Name							VARCHAR(100),
	Last_Log_Backup_Finish_DateTime		DATETIME,
	Backup_Type								VARCHAR(1) DEFAULT 'L',
	LogBackup_SetID						INT,
	Log_Backup_Path						VARCHAR(100)
)

DECLARE @Backup_Report TABLE
(
	Server_Name						VARCHAR(100),
	Server_IP						VARCHAR(20),
	Database_Name					VARCHAR(100),
	FullBackup_SetID				INT DEFAULT 0,
	DiffBackup_SetID				INT DEFAULT 0,
	LogBackup_SetID					INT DEFAULT 0,

	Last_Full_Backup_Start			DATETIME,
	Last_Full_Backup_End			DATETIME,
	Days_Since_Last_Full_Backup		INT,
	Last_Full_Backup_Size_GB		DECIMAL(19,3),

	Last_Diff_Backup_Start			DATETIME,
	Last_Diff_Backup_End			DATETIME,
	Days_Since_Last_Diff_Backup		INT,
	Last_Diff_Backup_Size_GB		DECIMAL(19,3),

	Last_Log_Backup_Start			DATETIME,
	Last_Log_Backup_End				DATETIME,
	Days_Since_Last_Log_Backup		INT,
	Last_Log_Backup_Size_GB			DECIMAL(19,3),

	Full_Backup_Path				VARCHAR(100),
	Diff_Backup_Path				VARCHAR(100),
	Log_Backup_Path					VARCHAR(100)

)

-- GET FULL BACKUP DETAILS : START
INSERT INTO @LAST_FULL_BACKUP_LIST (Database_Name, Last_Full_Backup_Finish_DateTime, FullBackup_SetID)
SELECT SYSDBLIST.name,
	MAX(BUSETS.backup_finish_date) AS Last_Backup_Finish_DateTime
	, MAX(backup_set_id)
FROM MASTER.sys.databases AS SYSDBLIST
	INNER JOIN msdb.dbo.backupset AS BUSETS ON SYSDBLIST.name = BUSETS.database_name
WHERE SYSDBLIST.name<>'TempDB' AND BUSETS.[type] ='D'
GROUP BY SYSDBLIST.name

UPDATE LFBL SET Full_Backup_Path = BMF.physical_device_name
FROM @LAST_FULL_BACKUP_LIST LFBL
	INNER JOIN msdb.dbo.backupmediafamily BMF ON LFBL.FullBackup_SetID = BMF.Media_Set_ID 

-- GET FULL BACKUP DETAILS : END

-- GET DIFF BACKUP DETAILS : START

INSERT INTO @LAST_DIFF_BACKUP_LIST (Database_Name, Last_Diff_Backup_Finish_DateTime, DiffBackup_SetID)
SELECT SYSDBLIST.name,
	MAX(BUSETS.backup_finish_date) AS Last_Backup_Finish_DateTime
	, MAX(backup_set_id)
FROM MASTER.sys.databases AS SYSDBLIST
	LEFT OUTER JOIN msdb.dbo.backupset AS BUSETS ON SYSDBLIST.name = BUSETS.database_name
WHERE SYSDBLIST.name<>'TempDB' AND BUSETS.[type] ='I'  
GROUP BY SYSDBLIST.name

UPDATE LDBL SET Diff_Backup_Path = BMF.physical_device_name
FROM @LAST_DIFF_BACKUP_LIST LDBL
	INNER JOIN msdb.dbo.backupmediafamily BMF ON LDBL.DiffBackup_SetID = BMF.Media_Set_ID 

-- GET DIFF BACKUP DETAILS : END


-- GET LOG BACKUP DETAILS : START

INSERT INTO @LAST_LOG_BACKUP_LIST (Database_Name, Last_Log_Backup_Finish_DateTime, LogBackup_SetID)
SELECT SYSDBLIST.name,
	MAX(BUSETS.backup_finish_date) AS Last_Backup_Finish_DateTime
	, MAX(backup_set_id)
FROM MASTER.sys.databases AS SYSDBLIST
	LEFT OUTER JOIN msdb.dbo.backupset AS BUSETS ON SYSDBLIST.name = BUSETS.database_name
WHERE SYSDBLIST.name<>'TempDB' AND BUSETS.[type] ='L'  
GROUP BY SYSDBLIST.name

UPDATE LLBL SET Log_Backup_Path = BMF.physical_device_name
FROM @LAST_LOG_BACKUP_LIST LLBL
	INNER JOIN msdb.dbo.backupmediafamily BMF ON LLBL.LogBackup_SetID = BMF.Media_Set_ID 

-- GET DIFF BACKUP DETAILS : END

INSERT INTO @Backup_Report (Server_Name, Server_IP, Database_Name)
SELECT @@SERVERNAME, CONVERT(VARCHAR(25), CONNECTIONPROPERTY('local_net_address')), Name 
FROM MASTER.sys.databases WHERE state_desc = 'ONLINE' AND Name <> 'TempDB'

UPDATE BRpt SET FullBackup_SetID = ISNULL(FBkp.FullBackup_SetID, 0), DiffBackup_SetID = ISNULL(DBkp.DiffBackup_SetID,0), LogBackup_SetID = ISNULL(LBkp.LogBackup_SetID,0)
  ,Full_Backup_Path = FBkp.Full_Backup_Path, Diff_Backup_Path = DBkp.Diff_Backup_Path, Log_Backup_Path = LBkp.Log_Backup_Path
FROM @Backup_Report BRpt
	LEFT JOIN @LAST_FULL_BACKUP_LIST FBkp ON BRpt.Database_Name = FBkp.Database_Name
	LEFT JOIN @LAST_DIFF_BACKUP_LIST DBkp ON BRpt.Database_Name = DBkp.Database_Name
	LEFT JOIN @LAST_LOG_BACKUP_LIST LBkp ON BRpt.Database_Name = LBkp.Database_Name

--SELECT * FROM @LAST_FULL_BACKUP_LIST
--SELECT * FROM @LAST_DIFF_BACKUP_LIST
--SELECT * FROM @Backup_Report

UPDATE BRpt SET Last_Full_Backup_Start = FullBKPSET.backup_start_date, Last_Full_Backup_End = FullBKPSET.backup_finish_date,
			Last_Full_Backup_Size_GB = ROUND(((FullBKPSET.Backup_Size/1024)/1024)/1024,3),
			Last_Diff_Backup_Start = DiffBKPSET.backup_start_date, Last_Diff_Backup_End = DiffBKPSET.backup_finish_date,
			Last_Diff_Backup_Size_GB = ROUND(((DiffBKPSET.Backup_Size/1024)/1024)/1024,3),
			Last_Log_Backup_Start = LogBKPSET.backup_start_date, Last_Log_Backup_End = LogBKPSET.backup_finish_date,
			Last_Log_Backup_Size_GB = ROUND(((LogBKPSET.Backup_Size/1024)/1024)/1024,3)
FROM @Backup_Report BRpt
	LEFT JOIN msdb.dbo.backupset FullBKPSET ON BRpt.FullBackup_SetID = FullBKPSET.backup_set_id
	LEFT JOIN msdb.dbo.backupset DiffBKPSET ON BRpt.DiffBackup_SetID = DiffBKPSET.backup_set_id
	LEFT JOIN msdb.dbo.backupset LogBKPSET ON BRpt.LogBackup_SetID = LogBKPSET.backup_set_id

UPDATE @Backup_Report SET Days_Since_Last_Full_Backup = (DATEDIFF(DAY,Last_Full_Backup_End ,GETDATE())),
						Days_Since_Last_Diff_Backup = (DATEDIFF(DAY,Last_Diff_Backup_End ,GETDATE())),
						Days_Since_Last_Log_Backup = (DATEDIFF(DAY,Last_Log_Backup_End ,GETDATE()))

--SELECT * FROM @LAST_FULL_BACKUP_LIST
--SELECT * FROM @LAST_DIFF_BACKUP_LIST
--SELECT * FROM @Backup_Report


SELECT @MaxDays_Since_Last_Full_Backup = MAX(Days_Since_Last_Full_Backup) FROM @Backup_Report
SELECT @MaxDays_Since_Last_Diff_Backup = MAX(Days_Since_Last_Diff_Backup) FROM @Backup_Report WHERE Database_Name NOT IN ('master','model','msdb')
SELECT @MaxDays_Since_Last_Log_Backup = MAX(Days_Since_Last_Log_Backup) FROM @Backup_Report WHERE Database_Name NOT IN ('master','model','msdb')


SELECT CONNECTIONPROPERTY('local_net_address') AS Server_IP, 
	@MaxDays_Since_Last_Full_Backup AS Days_Since_Last_Full_Backup, 
	@MaxDays_Since_Last_Diff_Backup AS Days_Since_Last_Diff_Backup
	, Min(Last_Full_Backup_Start) AS Last_Full_Backup_Start, MAX(Last_Full_Backup_End) AS Last_Full_Backup_End
	, Min(Last_Diff_Backup_Start) AS Last_Diff_Backup_Start, MAX(Last_Diff_Backup_End) AS Last_Diff_Backup_End
	, Min(Last_Log_Backup_Start) AS Last_Log_Backup_Start, MAX(Last_Log_Backup_End) AS Last_Log_Backup_End
	, MAX(Full_Backup_Path) AS Full_Backup_Path
	, MAX(Diff_Backup_Path) AS Diff_Backup_Path
	, MAX(Log_Backup_Path) AS Log_Backup_Path
FROM @Backup_Report


--SELECT * FROM  msdb.dbo.backupset WHERE backup_set_id= 8412
-- msdb.dbo.backupmediafamily
--SELECT * FROM msdb.dbo.backupmediafamily
