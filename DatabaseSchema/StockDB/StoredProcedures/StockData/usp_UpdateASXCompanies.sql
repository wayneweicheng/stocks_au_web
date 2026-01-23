-- Stored procedure: [StockData].[usp_UpdateASXCompanies]





CREATE PROCEDURE [StockData].[usp_UpdateASXCompanies]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCompanies as varchar(max)
AS
/******************************************************************************
File: usp_UpdateASXCompany.sql
Stored Procedure Name: usp_UpdateASXCompany
Overview
-----------------
usp_AddNewASXCode

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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_UpdateASXCompanies'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		if object_id(N'Tempdb.dbo.#TempStock') is not null
			drop table #TempStock

		create table #TempStock
		(
			ASXCode varchar(10),
			CompanyStatus varchar(20),
			CompanyName varchar(200),
			CompanyType varchar(100),
			MarketCap decimal(20, 4)
		)

		INSERT INTO #TempStock (ASXCode, CompanyStatus, CompanyName, CompanyType, MarketCap)
		SELECT 
			JSON_VALUE(value, '$.code') AS ASXCode,
			null AS CompanyStatus,
			JSON_VALUE(value, '$.name') AS CompanyName,
			JSON_VALUE(value, '$.sector') AS CompanyType,
			cast(JSON_VALUE(value, '$.market_cap') as bigint)*1.0/1000 AS MarketCap
		FROM 
			OPENJSON(@pvchASXCompanies) AS jsonData

		--SELECT 
		--	JSON_VALUE(value, '$.code') AS ASXCode,
		--	null AS CompanyStatus,
		--	JSON_VALUE(value, '$.name') AS CompanyName,
		--	JSON_VALUE(value, '$.sector') AS CompanyType,
		--	cast(JSON_VALUE(value, '$.market_cap') as bigint)*1.0/1000 AS MarketCap
		--into MAWork.dbo.CompanyName
		--FROM 
		--	OPENJSON(@pvchASXCompanies) AS jsonData

		update a
		set 
			ASXCode = a.ASXCode + '.AX',
			CompanyName = upper(CompanyName)
		from #TempStock as a

		-----------------

		update a
		set a.IsDisabled = 0,
			a.ASXCompanyName = b.CompanyName,
			a.[IndustryGroup] = b.CompanyType,
			a.MarketCap = b.MarketCap
		from Stock.ASXCompany as a
		inner join #TempStock as b
		on b.[ASXCode] = a.ASXCode
		and a.IsDisabled = 1

		update a
		set a.IsDisabled = 0,
			a.ASXCompanyName = b.CompanyName,
			a.[IndustryGroup] = b.CompanyType,
			a.MarketCap = b.MarketCap
		from Stock.ASXCompany as a
		inner join #TempStock as b
		on b.[ASXCode] = a.ASXCode
		and a.IsDisabled = 0

		insert into Stock.ASXCompany
		(
			   [ASXCode]
			  ,[ASXCompanyName]
			  ,[CreateDate]
			  ,[IndustryGroup]
			  ,[IsDisabled]
			  ,MarketCap
		)
		select
			   a.[ASXCode] as [ASXCode]
			  ,a.CompanyName as [ASXCompanyName]
			  ,getdate() as [CreateDate]
			  ,a.CompanyType as [IndustryGroup]
			  ,0 as [IsDisabled]
			  ,a.MarketCap
		from #TempStock as a
		where not exists
		(
			select 1
			from Stock.ASXCompany
			where ASXCode = a.[ASXCode]
		)
		and len(ASXCode) = 6

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
			where MonitorTypeID in ('A', 'H', 'I', 'O', 'P')
		) as b
		where a.IsDisabled = 0
		and not exists
		(
			select 1
			from StockData.MonitorStock
			where MonitorTypeID = b.MonitorTypeID
			and ASXCode = a.ASXCode
		)

		delete a
		from StockData.MonitorStock as a
		where MonitorTypeID in
		(
			select MonitorTypeID
			from LookupRef.MonitorType as b
			where MonitorTypeID in ('A', 'H', 'I', 'O', 'P')
		)
		and not exists
		(
			select 1
			from Stock.ASXCompany
			where ASXCode = a.ASXCode
			and IsDisabled = 0
		)

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