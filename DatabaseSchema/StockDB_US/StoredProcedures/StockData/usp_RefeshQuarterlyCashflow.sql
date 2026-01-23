-- Stored procedure: [StockData].[usp_RefeshQuarterlyCashflow]







CREATE PROCEDURE [StockData].[usp_RefeshQuarterlyCashflow]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefeshQuarterlyCashflow.sql
Stored Procedure Name: usp_RefeshQuarterlyCashflow
Overview
-----------------
usp_RefeshQuarterlyCashflow

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
Date:		2018-11-06
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefeshQuarterlyCashflow'
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
		if object_id(N'Tempdb.dbo.#TempCashPosition') is not null
			drop table #TempCashPosition

		select 
			AnnouncementID,
			ASXCode,
			AnnDateTime,
			AnnDescr,
			AnnContent,
			replace(ltrim(rtrim(DA_Utility.dbo.RegexReplace(replace(replace(AnnContent, char(13), '^'), char(10), '^'), '[^a-zA-Z0-9\.\,\+\''\s\%\|]', ' '))), '  ', ' ') as CleansedAnnContent, 
			DA_Utility.dbo.RegexMatch(replace(ltrim(rtrim(DA_Utility.dbo.RegexReplace(replace(replace(AnnContent, char(13), '^'), char(10), '^'), '[^a-zA-Z0-9\.\,\+\''\s\%\|]', ' '))), '  ', ' '), '(?<=cash.{0,80}\send\s.{0,10}[quarter|period|month].{0,20}\s)[\,0-9]{2,20}') as CashPositionRaw, 
			case when AnnContent like '%A_000%' then 1 else 0 end as ValueInAUDK,
			case when AnnContent like '%USD_000%' then 1 else 0 end as ValueInUSDK,
			cast(null as varchar(50)) as CashPositionVarchar,
			cast(null as bigint) as CashPosition
		into #TempCashPosition
		from StockData.Announcement as a
		where 
		(
			AnnDescr like '%Cash Flow%'
			or
			AnnDescr like '%CashFlow%'
			or
			' ' + AnnDescr + ' ' like '% 4C %'
			or
			AnnDescr like '%Appendix 4C%'
			or
			AnnDescr like '%Quarterly Activities Report%'
		)
		--and ASXCode = 'ICI.AX'
		--and not exists
		--(
		--	select 1
		--	from StockData.CashPosition
		--	where AnnouncementID = a.AnnouncementID
		--)
		order by AnnRetriveDateTime desc

		declare @intNum as int = 1

		while @intNum > 0
		begin
			update a
			set CleansedAnnContent = replace(CleansedAnnContent, '  ', ' ')
			from #TempCashPosition as a
			where charindex('  ', CleansedAnnContent, 0) > 0

			select @intNum = @@ROWCOUNT

			print @intNum
		end

		if object_id(N'Tempdb.dbo.#TempQuarterlyCashflow') is not null
			drop table #TempQuarterlyCashflow

		select 
			AnnouncementID,
			ASXCode,
			AnnDateTime,
			AnnDescr,
			CleansedAnnContent,
			isnull(DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=cash.{0,80}\send\s.{0,10}[quarter|period|month].{0,20}\s)[\,0-9\-]{2,20}'), DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=4.6\s{1,5})[\,0-9\-]{2,20}(?!\.)')) as Cash,
			isnull(DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=Receipts from.{0,80}\s(customer|customers)\s)[\,0-9\-]{1,20}(?!\.)'), DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=1.\s{1,5}Cash\s{1,5}flows\s{1,5}from\s{1,5}operating\s{1,5}activities\s{1,5})[\,0-9\-]{1,20}(?!\.)')) as ReceiptFromCustomer,
			case when DA_Utility.dbo.RegexMatch(CleansedAnnContent, 'Payments for.{0,80}\sresearch and development') is not null then isnull(DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=Payments for.{0,80}\sresearch and development\s)[\,0-9\-]{1,20}'), DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=1.2\s{1,5}payments\s{1,5}for\s{1,5})[\,0-9\-]{1,20}(?!\.)')) else null end as RandDCost,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=product\s{0,5}.{0,80}\s{0,5}manufacturing.{0,80}\s{1,5}operating costs\s{1,5})[\,0-9\-]{1,20}') as ManufacturingOperatingCost,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=c\s{1,5}advertising\s{1,5}and\s{1,5}marketing\s{1,5})[\,0-9\-]{1,20}') as AdandMarketingCost,

			case when DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(a|b|c)\s{1,5}exploration\s{0,5}.{0,10}\s{0,5}evaluation') is not null then isnull(DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=(a|b|c)\s{1,5}exploration\s{0,5}.{0,10}\s{0,5}evaluation\s{1,5})[\,0-9\-]{1,20}'), DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=1.2\s{1,5}payments\s{1,5}for\s{1,5})[\,0-9\-]{1,20}')) else null end as ExplorationandEvaluationCost,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=(a|b|c)\s{1,5}development\s{1,5})[\,0-9\-]{1,20}') as DevelopmentCost,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=(a|b|c)\s{1,5}production\s{1,5})[\,0-9\-]{1,20}') as ProductionCost,

			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=(c|d|e|f)\s{1,5}leased\s{1,5}assets\s{1,5})[\,0-9\-]{1,20}') as LeasedAssetCost,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=(c|d|e|f)\s{1,5}staff\s{1,5}costs\s{1,5})[\,0-9\-]{1,20}') as StaffCost,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=(c|d|e|f)\s{1,5}administration\s{1,5}and\s{1,5}corporate\s{1,5}costs\s{1,5})[\,0-9\-]{1,20}') as AdminandCorporateCost,
			isnull(DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=3.1\s{1,5}Proceeds\s{1,5}from\s{1,5}issues\s{1,5}of\s{1,5}shares\s{1,5})[\,0-9\-]{1,20}(?!\.)'), DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=3.\s{1,5}Cash\s{1,5}flows\s{1,5}from\s{1,5}financing\s{1,5}activities\s{1,5})[\,0-9\-]{1,20}(?!\.)')) as CashflowFromIssueOfShare,

			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=9.[0-9]\s{1,5}Research\s{1,5}and\s{1,5}development\s{1,5})[\,0-9\-]{1,20}(?!\.)') as NQRandDCost,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=9.[0-9]\s{1,5}product\s{0,5}.{0,80}\s{0,5}manufacturing.{0,80}\s{1,5}operating costs\s{1,5})[\,0-9\-]{1,20}(?!\.)') as NQManufacturingOperatingCost,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=9.[0-9]\s{1,5}advertising\s{1,5}and\s{1,5}marketing\s{1,5})[\,0-9\-]{1,20}(?!\.)') as NQAdandMarketingCost,

			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=9.[0-9]\s{1,5}exploration\s{0,5}.{0,10}\s{0,5}evaluation\s{1,5})[\,0-9\-]{1,20}') as NQExplorationandEvaluationCost,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=9.[0-9]\s{1,5}development\s{1,5})[\,0-9\-]{1,20}') as NQDevelopmentCost,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=9.[0-9]\s{1,5}production\s{1,5})[\,0-9\-]{1,20}') as NQProductionCost,

			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=9.[0-9]\s{1,5}leased\s{1,5}assets\s{1,5})[\,0-9\-]{1,20}(?!\.)') as NQLeasedAssetCost,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=9.[0-9]\s{1,5}staff\s{1,5}costs\s{1,5})[\,0-9\-]{1,20}(?!\.)') as NQStaffCost,
			DA_Utility.dbo.RegexMatch(CleansedAnnContent, '(?<=9.[0-9]\s{1,5}administration\s{1,5}and\s{1,5}corporate\s{1,5}costs\s{1,5})[\,0-9\-]{1,20}(?!\.)') as NQAdminandCorporateCost
		into #TempQuarterlyCashflow
		from #TempCashPosition
		
		delete a
		from #TempQuarterlyCashflow as a
		where isnull(Cash, '') = ''

		delete a
		from #TempQuarterlyCashflow as a
		where AnnDescr like '%Activities%'
		and AnnDescr not like '%cashflow%'
		and exists
		(
			select 1
			from #TempQuarterlyCashflow
			where ASXCode = a.ASXCode
			and cast(AnnDateTime as date) = cast(a.AnnDateTime as date)
			and AnnDescr like '%cashflow%'
			and AnnouncementID != a.AnnouncementID
		)

		update a
		set
		   [Cash] = replace(replace([Cash], ',', ''), '-', '')
		  ,[ReceiptFromCustomer] = replace(replace([ReceiptFromCustomer], ',', ''), '-', '')
		  ,[RandDCost] = replace(replace([RandDCost], ',', ''), '-', '')
		  ,[ManufacturingOperatingCost] = replace(replace([ManufacturingOperatingCost], ',', ''), '-', '')
		  ,[AdandMarketingCost] = replace(replace([AdandMarketingCost], ',', ''), '-', '')
		  ,[ExplorationandEvaluationCost] = replace(replace([ExplorationandEvaluationCost], ',', ''), '-', '')
		  ,[DevelopmentCost] = replace(replace([DevelopmentCost], ',', ''), '-', '')
		  ,[ProductionCost] = replace(replace([ProductionCost], ',', ''), '-', '')
		  ,[LeasedAssetCost] = replace(replace([LeasedAssetCost], ',', ''), '-', '')
		  ,[StaffCost] = replace(replace([StaffCost], ',', ''), '-', '')
		  ,[AdminandCorporateCost] = replace(replace([AdminandCorporateCost], ',', ''), '-', '')
		  ,[CashflowFromIssueOfShare] = replace(replace([CashflowFromIssueOfShare], ',', ''), '-', '')
		  ,[NQRandDCost] = replace(replace([NQRandDCost], ',', ''), '-', '')
		  ,[NQManufacturingOperatingCost] = replace(replace([NQManufacturingOperatingCost], ',', ''), '-', '')
		  ,[NQAdandMarketingCost] = replace(replace([NQAdandMarketingCost], ',', ''), '-', '')
		  ,[NQExplorationandEvaluationCost] = replace(replace([NQExplorationandEvaluationCost], ',', ''), '-', '')
		  ,[NQDevelopmentCost] = replace(replace([NQDevelopmentCost], ',', ''), '-', '')
		  ,[NQProductionCost] = replace(replace([NQProductionCost], ',', ''), '-', '')
		  ,[NQLeasedAssetCost] = replace(replace([NQLeasedAssetCost], ',', ''), '-', '')
		  ,[NQStaffCost] = replace(replace([NQStaffCost], ',', ''), '-', '')
		  ,[NQAdminandCorporateCost] = replace(replace([NQAdminandCorporateCost], ',', ''), '-', '')
		from #TempQuarterlyCashflow as a
		
		insert into Transform.QuarterlyCashflow
		(
		   [AnnouncementID]
		  ,[ASXCode]
		  ,[AnnDateTime]
		  ,[AnnDescr]
		  ,[CleansedAnnContent]
		  ,[Cash]
		  ,[ReceiptFromCustomer]
		  ,[RandDCost]
		  ,[ManufacturingOperatingCost]
		  ,[AdandMarketingCost]
		  ,[ExplorationandEvaluationCost]
		  ,[DevelopmentCost]
		  ,[ProductionCost]
		  ,[LeasedAssetCost]
		  ,[StaffCost]
		  ,[AdminandCorporateCost]
		  ,[CashflowFromIssueOfShare]
		  ,[NQRandDCost]
		  ,[NQManufacturingOperatingCost]
		  ,[NQAdandMarketingCost]
		  ,[NQExplorationandEvaluationCost]
		  ,[NQDevelopmentCost]
		  ,[NQProductionCost]
		  ,[NQLeasedAssetCost]
		  ,[NQStaffCost]
		  ,[NQAdminandCorporateCost]		
		)
		select 
		   [AnnouncementID]
		  ,[ASXCode]
		  ,[AnnDateTime]
		  ,[AnnDescr]
		  ,[CleansedAnnContent]
		  ,try_cast([Cash] as int)
		  ,try_cast([ReceiptFromCustomer] as int)
		  ,try_cast([RandDCost] as int)
		  ,try_cast([ManufacturingOperatingCost] as int)
		  ,try_cast([AdandMarketingCost] as int)
		  ,try_cast([ExplorationandEvaluationCost] as int)
		  ,try_cast([DevelopmentCost] as int)
		  ,try_cast([ProductionCost] as int)
		  ,try_cast([LeasedAssetCost] as int)
		  ,try_cast([StaffCost] as int)
		  ,try_cast([AdminandCorporateCost] as int)
		  ,try_cast([CashflowFromIssueOfShare] as int)
		  ,try_cast([NQRandDCost] as int)
		  ,try_cast([NQManufacturingOperatingCost] as int)
		  ,try_cast([NQAdandMarketingCost] as int)
		  ,try_cast([NQExplorationandEvaluationCost] as int)
		  ,try_cast([NQDevelopmentCost] as int)
		  ,try_cast([NQProductionCost] as int)
		  ,try_cast([NQLeasedAssetCost] as int)
		  ,try_cast([NQStaffCost] as int)
		  ,try_cast([NQAdminandCorporateCost] as int)
		from #TempQuarterlyCashflow as a
		where not exists
		(
			select 1
			from Transform.QuarterlyCashflow
			where AnnouncementID = a.AnnouncementID
		)

		update b
		set b.CashPosition = a.Cash
		from Transform.QuarterlyCashflow as a
		inner join StockData.CashPosition as b
		on a.ASXCode = b.ASXCode
		and a.AnnouncementID = b.AnnouncementID
		and a.Cash > 0
		and (b.CashPosition is null or b.CashPosition <= 0)

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
