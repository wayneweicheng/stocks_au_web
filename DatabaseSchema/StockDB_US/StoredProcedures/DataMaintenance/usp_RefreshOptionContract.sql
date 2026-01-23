-- Stored procedure: [DataMaintenance].[usp_RefreshOptionContract]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshOptionContract]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshOptionContract.sql
Stored Procedure Name: usp_RefreshOptionContract
Overview
-----------------
usp_RefreshOptionContract

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
Date:		2022-10-05
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshOptionContract'
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

		if object_id(N'Tempdb.dbo.#TempOptionContract') is not null
			drop table #TempOptionContract

		select 
			   [ASXCode]
			  ,replace([ASXCode], '.US', '') as [Underlying]
			  ,replace([OptionSymbol], ' ', '') as [OptionSymbol]
			  ,'N/A' as [Currency]
			  ,[Strike]
			  ,[PorC]
			  ,100 as [Multiplier]
			  ,cast(year(a.ExpiryDate) as varchar(10)) + right('0' + cast(month(a.ExpiryDate) as varchar(10)), 2) + right('0' + cast(day(a.ExpiryDate) as varchar(10)), 2) as [Expiry]
			  ,[ExpiryDate]
			  ,[Bid]
			  ,[BidSize]
			  ,[Ask]
			  ,[AskSize]
			  ,LastTradePrice as [Close]
			  ,[Delta]
			  ,[Gamma]
			  ,[Vega]
			  ,[Theta]
			  ,IV as [ImpliedVol]
			  ,getdate() as [CreateDateTime]
			  ,getdate() as [UpdateDateTime]
		into #TempOptionContract
		from
		(
			select *, row_number() over (partition by OptionSymbol order by ObservationDate desc) as RowNumber
			from StockData.v_OptionDelayedQuote
		) as a
		where RowNumber = 1

		update a
		set 
			   a.[OptionSymbol] = b.[OptionSymbol]
			  ,a.[Currency] = b.[Currency]
			  ,a.[Multiplier] = b.[Multiplier]
			  ,a.[Bid] = b.[Bid]
			  ,a.[BidSize] = b.[BidSize]
			  ,a.[Ask] = b.[Ask]
			  ,a.[AskSize] = b.[AskSize]
			  ,a.[Close] = b.[Close]
			  ,a.[Delta] = b.[Delta]
			  ,a.[Gamma] = b.[Gamma]
			  ,a.[Vega] = b.[Vega]
			  ,a.[Theta] = b.[Theta]
			  ,a.[ImpliedVol] = b.[ImpliedVol]
			  ,a.[UpdateDateTime] = b.[UpdateDateTime]
		from StockData.OptionContract as a
		inner join #TempOptionContract as b
		on b.ASXCode = a.ASXCode
		and b.PorC = a.PorC
		and b.ExpiryDate = a.ExpiryDate
		and b.Strike = a.Strike

		insert into StockData.OptionContract
		(
			   [ASXCode]
			  ,[Underlying]
			  ,[OptionSymbol]
			  ,[Currency]
			  ,[Strike]
			  ,[PorC]
			  ,[Multiplier]
			  ,[Expiry]
			  ,[ExpiryDate]
			  ,[Bid]
			  ,[BidSize]
			  ,[Ask]
			  ,[AskSize]
			  ,[Close]
			  ,[Delta]
			  ,[Gamma]
			  ,[Vega]
			  ,[Theta]
			  ,[ImpliedVol]
			  ,[CreateDateTime]
			  ,[UpdateDateTime]
		)
		select
			   [ASXCode]
			  ,[Underlying]
			  ,[OptionSymbol]
			  ,[Currency]
			  ,[Strike]
			  ,[PorC]
			  ,[Multiplier]
			  ,[Expiry]
			  ,[ExpiryDate]
			  ,[Bid]
			  ,[BidSize]
			  ,[Ask]
			  ,[AskSize]
			  ,[Close]
			  ,[Delta]
			  ,[Gamma]
			  ,[Vega]
			  ,[Theta]
			  ,[ImpliedVol]
			  ,[CreateDateTime]
			  ,[UpdateDateTime]
		from #TempOptionContract as a
		where not exists
		(
			select 1
			from StockData.OptionContract
			where ASXCode = a.ASXCode
			and PorC = a.PorC
			and ExpiryDate = a.ExpiryDate
			and Strike = a.Strike
		)

		update a
		set OptionSymbol = replace(OptionSymbol, ' ', '')
		from StockData.OptionContract as a
		where charindex(' ', OptionSymbol, 0) > 0

		update a
		set OptionSymbol = replace(OptionSymbol, ' ', '')
		from StockData.SignificantOptionTrade as a
		where charindex(' ', OptionSymbol, 0) > 0

		update a
		set OptionSymbol = replace(OptionSymbol, ' ', '')
		from StockData.OptionTrade as a
		where charindex(' ', OptionSymbol, 0) > 0

		update a
		set OptionSymbol = replace(OptionSymbol, ' ', '')
		from StockData.OptionBidAsk as a
		where charindex(' ', OptionSymbol, 0) > 0

		update a
		set a.ASXCode = 'SPXW.US'
		from StockData.OptionContract as a
		where ASXCode = '_SPX.US'
		and OptionSymbol like 'SPXW%'

		update a
		set a.ASXCode = 'SPX.US'
		from StockData.OptionContract as a
		where ASXCode = '_SPX.US'
		and OptionSymbol not like 'SPXW%'

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_DailyMaintainStockData failed'
		declare @vchEmailBody as varchar(2000) = @vchEmailSubject + ':
' + @vchErrorMessage

		exec msdb.dbo.sp_send_dbmail @profile_name='Wayne StockTrading',
		@recipients = @vchEmailRecipient,
		@subject = @vchEmailSubject,
		@body = @vchEmailBody

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
