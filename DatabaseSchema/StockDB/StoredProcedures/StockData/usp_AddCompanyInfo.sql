-- Stored procedure: [StockData].[usp_AddCompanyInfo]



CREATE PROCEDURE [StockData].[usp_AddCompanyInfo]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchCompanyInfo as varchar(max)
AS
/******************************************************************************
File: usp_AddCompanyInfo.sql
Stored Procedure Name: usp_AddCompanyInfo
Overview
-----------------
usp_AddCompanyInfo

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
Date:		2020-06-28
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddCompanyInfo'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @pvchASXCode as varchar(100) = 'PLS.AX'
		--declare @pvchCompanyInfo as varchar(100) = '{}'

		--Code goes here 
		if object_id(N'Tempdb.dbo.#TempCompanyInfoRaw') is not null
			drop table #TempCompanyInfoRaw

		select
			@pvchASXCode as ASXCode,
			@pvchCompanyInfo as CompanyInfo
		into #TempCompanyInfoRaw
		
		if object_id(N'Tempdb.dbo.#TempCompanyInfoBasic') is not null
			drop table #TempCompanyInfoBasic

		select distinct
			ASXCode, 
			json_value(CompanyInfo, '$.ASXCode') as StockCode, 
			json_value(CompanyInfo, '$.ScanDayTradeInfoUrl') as ScanDayTradeInfoUrl,
			json_value(CompanyInfo, '$.BusinessDetails') as BusinessDetails,
			json_value(CompanyInfo, '$.SharesOnIssue') as SharesOnIssue,
			json_value(CompanyInfo, '$.MarketCap') as MarketCap,
			json_value(CompanyInfo, '$.EPS') as EPS,
			json_value(CompanyInfo, '$.IndustryGroup') as IndustryGroup,
			json_value(CompanyInfo, '$.IndustrySubGroup') as IndustrySubGroup
		into #TempCompanyInfoBasic
		from #TempCompanyInfoRaw as a
		cross apply openjson(CompanyInfo) as b

		if object_id(N'Tempdb.dbo.#TempCompanyInfoTop20Raw') is not null
			drop table #TempCompanyInfoTop20Raw
			
		select
			ASXCode, 
			b.value as Top20Holders,
			c.value as Top20Holder,
			json_value(c.value, '$.NumberOfSecurity') as NumberOfSecurity,
			json_value(c.value, '$.HolderName') as HolderName,
			json_value(c.value, '$.CurrDate') as CurrDate,
			json_value(c.value, '$.PrevDate') as PrevDate,
			json_value(c.value, '$.CurrRank') as CurrRank,
			json_value(c.value, '$.PrevRank') as PrevRank,
			json_value(c.value, '$.CurrShares') as CurrShares,
			json_value(c.value, '$.PrevShares') as PrevShares,
			json_value(c.value, '$.CurrSharesPerc') as CurrSharesPerc,
			json_value(c.value, '$.PrevSharesPerc') as PrevSharesPerc,
			json_value(c.value, '$.ShareDiff') as ShareDiff
		into #TempCompanyInfoTop20Raw
		from #TempCompanyInfoRaw as a
		cross apply openjson(CompanyInfo) as b
		cross apply openjson(b.value) as c
		where b.[Key] = 'Top20Holders'
		
		if object_id(N'Tempdb.dbo.#TempCompanyInfoBasicTransformed') is not null
			drop table #TempCompanyInfoBasicTransformed

		select
	       [ASXCode]
		  ,[StockCode]
		  ,left([ScanDayTradeInfoUrl], 2000) as [ScanDayTradeInfoUrl]
		  ,left([BusinessDetails], 2000) as [BusinessDetails]
		  ,try_cast(replace([SharesOnIssue], ',', '') as bigint) as [SharesOnIssue]
		  ,try_cast(replace([MarketCap], ',', '') as bigint) as [MarketCap]
		  ,cast(null as decimal(20, 2)) as CleansedMarketCap
		  ,try_cast(replace([EPS], ',', '') as decimal(10, 4)) as [EPS]
		  ,left([IndustryGroup], 200) as [IndustryGroup]
		  ,left([IndustrySubGroup], 200) as [IndustrySubGroup]
		into #TempCompanyInfoBasicTransformed
		from #TempCompanyInfoBasic

		update a
		set SharesOnIssue = null
		from #TempCompanyInfoBasicTransformed as a
		where SharesOnIssue = 0

		update a
		set MarketCap = null
		from #TempCompanyInfoBasicTransformed as a
		where MarketCap = 0

		update a
		set CleansedMarketCap = MarketCap/1000000.0
		from #TempCompanyInfoBasicTransformed as a
		where MarketCap > 0

		update a
		set EPS = null
		from #TempCompanyInfoBasicTransformed as a
		where EPS = 0

		update a
		set BusinessDetails = null
		from #TempCompanyInfoBasicTransformed as a
		where not len(BusinessDetails) > 0

		delete a
		from #TempCompanyInfoBasicTransformed as a
		where MarketCap is null
		and BusinessDetails is null
		and SharesOnIssue is null

		delete a
		from [StockData].[CompanyInfoHistory] as a
		inner join [StockData].[CompanyInfo] as b
		on a.ASXCode = b.ASXCode
		and a.LastValidateDate = b.LastValidateDate
		inner join #TempCompanyInfoBasicTransformed as c
		on a.ASXCode = c.ASXCode

		insert into [StockData].[CompanyInfoHistory]
		(
			[ASXCode],
			[StockCode],
			[ScanDayTradeInfoUrl],
			[BusinessDetails],
			[SharesOnIssue],
			[MarketCap],
			[CleansedMarketCap],
			[EPS],
			[IndustryGroup],
			[IndustrySubGroup],
			[DateFrom],
			[DateTo],
			[LastValidateDate]
		)
		select
			a.[ASXCode],
			a.[StockCode],
			a.[ScanDayTradeInfoUrl],
			a.[BusinessDetails],
			a.[SharesOnIssue],
			a.[MarketCap],
			a.[CleansedMarketCap],
			a.[EPS],
			a.[IndustryGroup],
			a.[IndustrySubGroup],
			[DateFrom],
			[DateTo],
			[LastValidateDate]
		from [StockData].[CompanyInfo] as a
		inner join #TempCompanyInfoBasicTransformed as b
		on a.ASXCode = b.ASXCode

		delete a
		from [StockData].[CompanyInfo] as a
		inner join #TempCompanyInfoBasicTransformed as b
		on a.ASXCode = b.ASXCode

		insert into [StockData].[CompanyInfo]
		(
		   [ASXCode]
		  ,[StockCode]
		  ,[ScanDayTradeInfoUrl]
		  ,[BusinessDetails]
		  ,[SharesOnIssue]
		  ,[MarketCap]
		  ,[CleansedMarketCap]
		  ,[EPS]
		  ,[IndustryGroup]
		  ,[IndustrySubGroup]
		  ,[DateFrom]
		  ,[DateTo]
		  ,[LastValidateDate]
		)
		select 
		   [ASXCode]
		  ,[StockCode]
		  ,[ScanDayTradeInfoUrl]
		  ,left([BusinessDetails], 2000) as [BusinessDetails]
		  ,[SharesOnIssue]
		  ,[MarketCap]
		  ,[CleansedMarketCap]
		  ,[EPS]
		  ,[IndustryGroup]
		  ,[IndustrySubGroup]
		  ,getdate() as [DateFrom]
		  ,null as [DateTo]
		  ,getdate() as [LastValidateDate]
		from #TempCompanyInfoBasicTransformed as a

		delete a
		from [StockData].[CompanyInfoHistory] as a
		inner join [StockData].[CompanyInfo] as b
		on a.ASXCode = b.ASXCode
		and a.LastValidateDate = b.LastValidateDate
		inner join #TempCompanyInfoBasicTransformed as c
		on a.ASXCode = c.ASXCode

		insert into [StockData].[CompanyInfoHistory]
		(
			[ASXCode],
			[StockCode],
			[ScanDayTradeInfoUrl],
			[BusinessDetails],
			[SharesOnIssue],
			[MarketCap],
			[CleansedMarketCap],
			[EPS],
			[IndustryGroup],
			[IndustrySubGroup],
			[DateFrom],
			[DateTo],
			[LastValidateDate]
		)
		select
			a.[ASXCode],
			a.[StockCode],
			a.[ScanDayTradeInfoUrl],
			a.[BusinessDetails],
			a.[SharesOnIssue],
			a.[MarketCap],
			a.[CleansedMarketCap],
			a.[EPS],
			a.[IndustryGroup],
			a.[IndustrySubGroup],
			[DateFrom],
			[DateTo],
			[LastValidateDate]
		from [StockData].[CompanyInfo] as a
		inner join #TempCompanyInfoBasicTransformed as b
		on a.ASXCode = b.ASXCode

		if object_id(N'Tempdb.dbo.#TempCompanyInfoTop20Transformed') is not null
			drop table #TempCompanyInfoTop20Transformed
		
		select 
			ASXCode, 
			try_cast(NumberOfSecurity as bigint) as NumberOfSecurity,
			HolderName as HolderName,
			try_cast(CurrDate as date) as CurrDate,
			try_cast(PrevDate as date) as PrevDate,
			try_cast(CurrRank as int) as CurrRank,
			try_cast(PrevRank as int) as PrevRank,
			try_cast(replace(CurrShares, ',', '') as bigint) as CurrShares,
			try_cast(replace(PrevShares, ',', '') as bigint) as PrevShares,
			try_cast(CurrSharesPerc as decimal(20, 4)) as CurrSharesPerc,
			try_cast(PrevSharesPerc as decimal(20, 4)) as PrevSharesPerc,
			try_cast(ShareDiff as bigint) as ShareDiff
		into #TempCompanyInfoTop20Transformed
		from #TempCompanyInfoTop20Raw

		delete a
		from [StockData].[Top20Holder] as a
		inner join #TempCompanyInfoTop20Transformed as b
		on a.ASXCode = b.ASXCode
		and a.CurrDate = b.CurrDate

		insert into [StockData].[Top20Holder]
		(
		   [ASXCode]
		  ,[NumberOfSecurity]
		  ,[HolderName]
		  ,[CurrDate]
		  ,[PrevDate]
		  ,[CurrRank]
		  ,[PrevRank]
		  ,[CurrShares]
		  ,[PrevShares]
		  ,[CurrSharesPerc]
		  ,[PrevSharesPerc]
		  ,[ShareDiff]
		  ,[CreateDate]
		)
		select
		   [ASXCode]
		  ,[NumberOfSecurity]
		  ,[HolderName]
		  ,[CurrDate]
		  ,[PrevDate]
		  ,[CurrRank]
		  ,[PrevRank]
		  ,[CurrShares]
		  ,[PrevShares]
		  ,[CurrSharesPerc]
		  ,[PrevSharesPerc]
		  ,[ShareDiff]
		  ,getdate() as [CreateDate]
		from #TempCompanyInfoTop20Transformed
		
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
