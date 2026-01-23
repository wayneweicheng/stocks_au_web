-- Stored procedure: [DataMaintenance].[usp_RefreshASXCode]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshASXCode]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshASXCode.sql
Stored Procedure Name: usp_RefreshASXCode
Overview
-----------------
usp_RefreshASXCode

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2018-02-24
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
*******************************************************************************/

SET NOCOUNT ON

BEGIN --Proc

	IF @pintErrorNumber <> 0
	BEGIN
		-- Assume the application is in an error state, so get out quickly
		-- Remove this check if this stored procedure should run regardless of a previous error
		RETURN @pintErrorNumber
	END

	BEGIN TRY

		-- Error variable declarations
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshASXCode'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		--DOWNLOAD FILE ASXListedCompanies.csv FROM https://www.asx.com.au/asx/research/listedCompanies.do
		--AND PLACE IT IN THE FOLLOWING DIRECTORY C:\Temp\ASXListedCompanies.csv

		--REMOVE THE FIRST 2 LINES OF THE FILE, AS THEY ARE NOT COLUMN HEADER

		--IF MAWORK.[dbo].[ASXListedCompanies] ALREADY EXIST, PLEASE TRUNCATE IT
		truncate table MAWORK.[dbo].[ASXListedCompanies]

		----IMPORT THE FILE INTO MAWORK AS dbo.ASXListedCompanies
		--select top 1000 * from MAWORK.[dbo].[ASXListedCompanies]

		update a
		set [Company Name] = replace([Company Name], '"', ''),
			[ASX Code] = replace([ASX Code], '"', ''),
			[GICS industry group] = replace([GICS industry group], '"', '')
		from MAWORK.[dbo].[ASXListedCompanies] as a

		update a
		set [ASX code] = rtrim(ltrim([ASX code])) + '.AX'
		from MAWORK.[dbo].[ASXListedCompanies] as a

		delete a
		from MAWORK.dbo.ASXListedCompanies as a
		where len([ASX code]) > 7

		update a
		set IsDisabled = 1
		from Stock.ASXCompany as a
		where not exists
		(
			select 1
			from MAWORK.dbo.ASXListedCompanies
			where [ASX code] = a.ASXCode
		)
		and IsDisabled = 0

		update a
		set a.IsDisabled = 0,
			a.ASXCompanyName = b.[Company name],
			a.[IndustryGroup] = [GICS industry group]
		from Stock.ASXCompany as a
		inner join MAWORK.dbo.ASXListedCompanies as b
		on b.[ASX code] = a.ASXCode
		and a.IsDisabled = 1

		delete a
		from MAWORK.dbo.ASXListedCompanies as a
		inner join
		(
			select [ASX code]
			from MAWORK.dbo.ASXListedCompanies as a
			group by [ASX code]
			having count(*) > 1
		) as b
		on a.[ASX code] = b.[ASX code]

		insert into Stock.ASXCompany
		(
			   [ASXCode]
			  ,[ASXCompanyName]
			  ,[CreateDate]
			  ,[IndustryGroup]
			  ,[IsDisabled]
		)
		select
			   a.[ASX code] as [ASXCode]
			  ,a.[Company name] as [ASXCompanyName]
			  ,getdate() as [CreateDate]
			  ,[GICS industry group] as [IndustryGroup]
			  ,0 as [IsDisabled]
		from MAWORK.dbo.ASXListedCompanies as a
		where not exists
		(
			select 1
			from Stock.ASXCompany
			where ASXCode = a.[ASX code]
		)

		if object_id(N'Tempdb.dbo.#TempAlertType') is not null
			drop table #TempAlertType

		select distinct AlertTypeID
		into #TempAlertType
		from [Stock].[ASXAlertSetting]

		delete a
		from [Stock].[ASXAlertSetting] as a

		insert into [Stock].[ASXAlertSetting]
		(
			   [ASXCode]
			  ,[AlertTypeID]
			  ,[CreateDate]
			  ,[StockUserID]
		)
		select
			   [ASXCode]
			  ,[AlertTypeID]
			  ,getdate() as [CreateDate]
			  ,1 as [StockUserID]
		from [Stock].[ASXCompany] as a
		cross join 
		(
			select distinct AlertTypeID
			from #TempAlertType
		) as b
		where a.IsDisabled = 0

		delete a
		from [Stock].[StockStats] as a

		dbcc checkident('[Stock].[StockStats]', reseed, 1);

		insert into [Stock].[StockStats]
		(
			   [ASXCode]
			  ,[IsTrendFlatOrUp]
			  ,[LatestPrice]
			  ,[LastUpdateDate]
		)
		select
			   [ASXCode]
			  ,null as [IsTrendFlatOrUp]
			  ,null as [LatestPrice]
			  ,null as [LastUpdateDate]
		from [Stock].[ASXCompany] as a
		where IsDisabled = 0

		insert into [BackTest].[ExecutionSettingStock]
		(
			   [ExecutionSettingID]
			  ,[ASXCode]
			  ,[IsDisabled]
			  ,[CreateDate]
		)
		select
			   1 as [ExecutionSettingID]
			  ,[ASXCode]
			  ,[IsDisabled]
			  ,[CreateDate]
		from [Stock].[ASXCompany] as a
		where not exists
		(
			select 1
			from [BackTest].[ExecutionSettingStock]
			where ASXCode = a.ASXCode
			and ExecutionSettingID = 1
		)

		--select top 100 a.MonitorTypeID, b.MonitorTypeDescr, count(*) 
		--from StockData.MonitorStock as a
		--left join LookupRef.MonitorType as b
		--on a.MonitorTypeID = b.MonitorTypeID
		--group by a.MonitorTypeID, b.MonitorTypeDescr

		delete a
		from StockData.MonitorStock as a
		where MonitorTypeID not in ('C', 'M')

		insert into StockData.MonitorStock
		(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,[MonitorTypeID]
			  ,[LastCourseOfSaleDate]
			  ,[StockSource]
		)
		select
			   [ASXCode]
			  ,getdate() as [CreateDate]
			  ,null as [LastUpdateDate]
			  ,null as [UpdateStatus]
			  ,[MonitorTypeID]
			  ,null as [LastCourseOfSaleDate]
			  ,null as [StockSource]
		from [Stock].[ASXCompany] as a
		cross join 
		(
			select MonitorTypeID 
			from LookupRef.MonitorType as b
			where MonitorTypeID not in ('C', 'M')
		) as b
		where a.IsDisabled = 0

		--select top 100 a.MonitorTypeID, b.MonitorTypeDescr, count(*) 
		--from StockData.MonitorStock as a
		--left join LookupRef.MonitorType as b
		--on a.MonitorTypeID = b.MonitorTypeID
		--group by a.MonitorTypeID, b.MonitorTypeDescr
		
	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
	END CATCH

	IF @intErrorNumber = 0 OR @vchErrorProcedure = ''
	BEGIN
		-- No Error occured in this procedure

		--COMMIT TRANSACTION 

		IF @pbitDebug = 1
		BEGIN
			PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName + ' finished executing (successfully) at ' + CAST(getdate() as varchar(20))
		END
	END

	ELSE
	BEGIN

		--IF @@TRANCOUNT > 0
		--BEGIN
		--	ROLLBACK TRANSACTION
		--END
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
