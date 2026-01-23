-- Stored procedure: [StockData].[usp_RefreshASXCompanyList]






CREATE PROCEDURE [StockData].[usp_RefreshASXCompanyList]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshASXCompanyList.sql
Stored Procedure Name: usp_RefreshASXCompanyList
Overview
-----------------
usp_AddASXCompanyList

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
Date:		2023-11-12
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshASXCompanyList'
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
		--begin transaction
		
		--@pxmlMarketDepth

		set dateformat dmy

		update a
		set CleansedListingDate = cast(ListingDate as date),
			CleansedMarket = try_cast(replace(MarketCap, ',', '') as bigint)/1000.0
		from [Working].[ASXCompanyList] as a

		declare @intExpired as int

		select @intExpired = count(*)
		from Stock.ASXCompany as a
		where not exists
		(
			select 1
			from [Working].[ASXCompanyList]
			where [ASXcode] = a.ASXCode
		)
		and IsDisabled = 0

		--select @intExpired 

		if @intExpired > 300
		begin
			raiserror('Number of expired records over threshold', 16, 0)
		end
		else
		begin
			update a
			set a.IsDisabled = 1,
				a.LastUpdateDate = getdate()
			from Stock.ASXCompany as a
			where not exists
			(
				select 1
				from [Working].[ASXCompanyList]
				where [ASXcode] = a.ASXCode
			)
			and IsDisabled = 0

			update a
			set a.IsDisabled = 0,
				a.ASXCompanyName = b.ASXCompanyName,
				a.IndustryGroup = b.IndustryGroup,
				a.MarketCap = b.[CleansedMarket],
				a.ListingDate = b.CleansedListingDate,
				a.LastUpdateDate = getdate()
			from Stock.ASXCompany as a
			inner join Working.ASXCompanyList as b
			on a.ASXCode = b.ASXCode

			insert into Stock.ASXCompany
			(
				   [ASXCode]
				  ,[ASXCompanyName]
				  ,[CreateDate]
				  ,[IndustryGroup]
				  ,[IsDisabled]
				  ,ListingDate
				  ,MarketCap
				  ,LastUpdateDate
			)
			select
				   a.[ASXcode] as [ASXCode]
				  ,a.ASXCompanyName as [ASXCompanyName]
				  ,getdate() as [CreateDate]
				  ,[IndustryGroup] as [IndustryGroup]
				  ,0 as [IsDisabled]
				  ,CleansedListingDate
				  ,CleansedMarket
				  ,getdate() as LastUpdateDate
			from [Working].[ASXCompanyList] as a
			where not exists
			(
				select 1
				from Stock.ASXCompany
				where ASXCode = a.[ASXCode]
			)

			delete a
			from [Stock].[ASXAlertSetting] as a
			inner join LookupRef.AlertType as b
			on a.AlertTypeID = b.AlertTypeID
		
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
				select AlertTypeID
				from LookupRef.AlertType
			) as b
			where a.IsDisabled = 0

			truncate table [Stock].[StockStats]

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

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('C')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('M')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('A')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			insert into StockData.MonitorStock
			(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,[MonitorTypeID]
			)
			select
			   [ASXCode]
			  ,getdate() as[CreateDate]
			  ,null as [LastUpdateDate]
			  ,null as [UpdateStatus]
			  ,'A' as [MonitorTypeID]
			from Stock.ASXCompany as a
			where not exists
			(
				select 1
				from StockData.MonitorStock
				where ASXCode = a.ASXCode
				and MonitorTypeID = 'A'
				
			)
			and a.IsDisabled = 0

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('O')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			insert into StockData.MonitorStock
			(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,[MonitorTypeID]
			)
			select
			   [ASXCode]
			  ,getdate() as[CreateDate]
			  ,null as [LastUpdateDate]
			  ,null as [UpdateStatus]
			  ,'O' as [MonitorTypeID]
			from Stock.ASXCompany as a
			where not exists
			(
				select 1
				from StockData.MonitorStock
				where ASXCode = a.ASXCode
				and MonitorTypeID = 'O'
			)
			and a.IsDisabled = 0

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('P')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			insert into StockData.MonitorStock
			(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,[MonitorTypeID]
			)
			select
			   [ASXCode]
			  ,getdate() as[CreateDate]
			  ,null as [LastUpdateDate]
			  ,null as [UpdateStatus]
			  ,'P' as [MonitorTypeID]
			from Stock.ASXCompany as a
			where not exists
			(
				select 1
				from StockData.MonitorStock
				where ASXCode = a.ASXCode
				and MonitorTypeID = 'P'
			)
			and a.IsDisabled = 0

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('H')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			insert into StockData.MonitorStock
			(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,[MonitorTypeID]
			)
			select
			   [ASXCode]
			  ,getdate() as[CreateDate]
			  ,null as [LastUpdateDate]
			  ,null as [UpdateStatus]
			  ,'H' as [MonitorTypeID]
			from Stock.ASXCompany as a
			where not exists
			(
				select 1
				from StockData.MonitorStock
				where ASXCode = a.ASXCode
				and MonitorTypeID = 'H'
			)
			and a.IsDisabled = 0

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('E')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			insert into StockData.MonitorStock
			(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,[MonitorTypeID]
			)
			select
			   [ASXCode]
			  ,getdate() as[CreateDate]
			  ,null as [LastUpdateDate]
			  ,null as [UpdateStatus]
			  ,'E' as [MonitorTypeID]
			from Stock.ASXCompany as a
			where not exists
			(
				select 1
				from StockData.MonitorStock
				where ASXCode = a.ASXCode
				and MonitorTypeID = 'E'
			)
			and a.IsDisabled = 0

			update a
			set a.MarketCap = b.MarketCap*1000,
				a.CleansedMarketCap = cast(b.MarketCap/1000.0 as decimal(20, 2)),
				a.IndustryGroup = b.IndustryGroup
			from StockData.CompanyInfo as a
			inner join Stock.ASXCompany as b
			on a.ASXCode = b.ASXCode
			and b.IsDisabled = 0
			where DateTo is null

			update a
			set a.DateTo = getdate()
			from StockData.CompanyInfo as a
			left join Stock.ASXCompany as b
			on a.ASXCode = b.ASXCode
			and b.IsDisabled = 0
			where b.ASXCode is null
			and a.DateTo is null

			insert into StockData.CompanyInfo
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
				ASXCode as [ASXCode],
				substring(a.ASXCode, 1, charindex('.', a.ASXCode, 0) - 1) as [StockCode],
				null as [ScanDayTradeInfoUrl],
				null as [BusinessDetails],
				null as [SharesOnIssue],
				MarketCap*1000 as [MarketCap],
				cast(a.MarketCap/1000.0 as decimal(20, 2)) as [CleansedMarketCap],
				null as [EPS],
				[IndustryGroup] as [IndustryGroup],
				null as [IndustrySubGroup],
				getdate() as [DateFrom],
				null as [DateTo],
				getdate() as [LastValidateDate]
			from Stock.ASXCompany as a
			where IsDisabled = 0
			and charindex ('.', ASXCode, 0) > 0
			and not exists
			(
				select 1
				from StockData.CompanyInfo
				where ASXCode = a.ASXCode
				and DateTo is null
			)

			
		end
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
