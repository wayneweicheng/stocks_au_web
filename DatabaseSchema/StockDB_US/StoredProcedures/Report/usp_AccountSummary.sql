-- Stored procedure: [Report].[usp_AccountSummary]





CREATE PROCEDURE [Report].[usp_AccountSummary]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_AccountSummary.sql
Stored Procedure Name: usp_AccountSummary
Overview
-----------------
usp_AccountSummary

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
Date:		2016-06-13
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AccountSummary'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'Report'
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
		exec sp_rename '[dbo].[Statement-297465-20111012-20171111]."Date"', 'Date', 'Column'

		exec sp_rename '[dbo].[Statement-297465-20111012-20171111].["Reference"]', 'Reference', 'Column'

		exec sp_rename '[dbo].[Statement-297465-20111012-20171111].["Type"]', 'Type', 'Column'

		exec sp_rename '[dbo].[Statement-297465-20111012-20171111].["Description"]', 'Description', 'Column'

		exec sp_rename '[dbo].[Statement-297465-20111012-20171111].["Credit $"]', 'Credit', 'Column'

		exec sp_rename '[dbo].[Statement-297465-20111012-20171111].["Debit $"]', 'Debit', 'Column'

		exec sp_rename '[dbo].[Statement-297465-20111012-20171111].["Balance $"]', 'Balance', 'Column'

		set dateformat dmy

		if object_id(N'dbo.AccountStatement') is not null
			drop table dbo.AccountStatement

		select 
			 DA_Utility.[dbo].[RegexMatch]([Description], '(?<=(Bght|Sold) )[0-9]{1,10}(?= )') as StockAmount
			,DA_Utility.[dbo].[RegexMatch]([Description], '(?<=(Bght|Sold) [0-9]{1,10} )[0-9A-Z]{3,5}(?= @)') as ASXCode
			,DA_Utility.[dbo].[RegexMatch]([Description], '(?<=(Bght|Sold) [0-9]{1,10} [0-9A-Z]{3,5} @ )[0-9.]+') as StockPrice
			,cast([Date] as date) as TransactionDate
			,* 
		into dbo.AccountStatement
		from [dbo].[Statement-297465-20111012-20171111]
		where [Description] != 'Open Balance'
		--and [Type] in ('CB', 'CS')

		update a
		set Debit = nullif(Debit, '')
		from dbo.AccountStatement as a

		update a
		set Credit = nullif(Credit, '')
		from dbo.AccountStatement as a

		alter table dbo.AccountStatement
		alter column Debit decimal(20, 5)

		alter table dbo.AccountStatement
		alter column Credit decimal(20, 5)

		select * from dbo.AccountStatement
		where ASXCode = 'TAW'

		if object_id(N'Tempdb.dbo.#TempPL') is not null
			drop table #TempPL

		select 
			ASXCode, 
			sum(Credit) - sum(Debit) as ProfitLoss,
			sum(case when [Type] = 'CB' then StockAmount else -1*StockAmount end) as StockLeft,
			max(TransactionDate) as TransactionDate
		into #TempPL
		from dbo.AccountStatement
		where [Type] in ('CB', 'CS')
		--where ASXCode = 'AZS'
		group by ASXCode
		order by max(TransactionDate)

		if object_id(N'Tempdb.dbo.#TempPrice') is not null
			drop table #TempPrice

		select
			ASXCode,
			[Close]
		into #TempPrice
		from
		(
		select 
			ASXCode,
			[Close],
			ROW_NUMBER() over (partition by ASXCode order by ObservationDate desc) as RowNumber
		from StockData.PriceHistory
		) as x
		where RowNumber = 1

		select cast(year(TransactionDate) as varchar(50)) + '-' + right('0' + cast(month(TransactionDate) as varchar(50)), 2), sum(ProfitLoss) as TotalProfitLoss, sum(case when ProfitLoss is not null then a.StockLeft*b.[Close] end) as StockAmountLeft 
		from #TempPL as a
		left join #TempPrice as b
		on a.ASXCode + '.AX' = b.ASXCode
		group by cast(year(TransactionDate) as varchar(50)) + '-' + right('0' + cast(month(TransactionDate) as varchar(50)), 2)
		order by cast(year(TransactionDate) as varchar(50)) + '-' + right('0' + cast(month(TransactionDate) as varchar(50)), 2)

		select sum(ProfitLoss) as TotalProfitLoss, sum(case when ProfitLoss is not null then a.StockLeft*b.[Close] end) as StockAmountLeft 
		from #TempPL as a
		left join #TempPrice as b
		on a.ASXCode + '.AX' = b.ASXCode
		
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
