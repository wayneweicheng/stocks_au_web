-- Stored procedure: [StockData].[usp_AddOptionTrade_Batch]




CREATE PROCEDURE [StockData].[usp_AddOptionTrade_Batch]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchTradeBar varchar(max)
AS
/******************************************************************************
File: usp_AddOptionTrade_Batch.sql
Stored Procedure Name: usp_AddOptionTrade_Batch
Overview
-----------------
usp_AddOptionTrade

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
Date:		2022-07-15
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddOptionTrade_Batch'
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
		set dateformat ymd

		--if object_id(N'Working.TradeBar') is not null
		--	drop table Working.TradeBar

		--select @pvchTradeBar as TradeBar
		--into Working.TradeBar

		--return

		if object_id(N'Tempdb.dbo.#TempOptionTradeBar') is not null
			drop table #TempOptionTradeBar

		select
			@pvchTradeBar as TradeBar
		into #TempOptionTradeBar

		if object_id(N'Tempdb.dbo.#TempOptionTrade') is not null
			drop table #TempOptionTrade

		create table #TempOptionTrade
		(
			OptionTradeID int identity(1, 1) not null,
			ASXCode varchar(10) not null,
			Underlying varchar(10) not null,
			OptionSymbol varchar(100) not null,
			SaleTime datetime,
			Price decimal(20, 4),
			Size bigint,
			Exchange varchar(100),
			SpecialConditions varchar(200),
			ObservationDateLocal date,
			Strike decimal(20, 4),
			PorC char(1),
			ExpiryDate date,
			Expiry varchar(8)
		)

		insert into #TempOptionTrade
		(
			ASXCode,
			Underlying,
			OptionSymbol,
			SaleTime,
			Price,
			Size,
			Exchange,
			SpecialConditions,
			ObservationDateLocal,
			Strike,
			PorC,
			ExpiryDate,
			Expiry
		)
		select distinct
			json_value(b.value, '$.underlying') +'.US' as ASXCode,
			json_value(b.value, '$.underlying') as Underlying, 
			json_value(b.value, '$.OptionSymbol') as OptionSymbol,
			left(json_value(b.value, '$.Saletime'), 19) as Saletime, 
			try_cast(json_value(b.value, '$.Price') as decimal(20, 4)) as Price,
			floor(cast(json_value(b.value, '$.Size') as decimal(20, 4))) as Size,
			json_value(b.value, '$.Exchange') as Exchange,
			json_value(b.value, '$.SpecialConditions') as SpecialConditions,
			null as ObservationDateLocal,
			cast(null as decimal(20, 4)) as Strike,
			cast(null as char(1)) as PorC,
			cast(null as date) as ExpiryDate,
			cast(null as varchar(8)) as Expiry
		--from #TempOptionTradeBar as a
		from #TempOptionTradeBar as a
		cross apply openjson(TradeBar) as b

		update a
		set ObservationDateLocal = cast(CONVERT(datetime, SWITCHOFFSET(SaleTime, DATEPART(TZOFFSET, SaleTime AT TIME ZONE 'Eastern Standard Time'))) as date)
		from #TempOptionTrade as a

		update a
		set 
			Strike = cast(reverse(substring(reverse(OptionSymbol), 1, 8)) as decimal(20, 4))/1000.0,
			PorC = reverse(substring(reverse(OptionSymbol), 9, 1)),
			ExpiryDate = '20' + left(reverse(substring(reverse(OptionSymbol), 10, 6)), 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 3, 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 5, 2)	
		from #TempOptionTrade as a

		update a
		set ExpiryDate = dateadd(day, -1, ExpiryDate)
		from #TempOptionTrade as a
		where ASXCode = 'SPX.US'

		update a
		set Expiry = convert(varchar(8), ExpiryDate, 112)
		from #TempOptionTrade as a

		--if object_id(N'Tempdb.dbo.#TempOptionTrade') is not null
		--	drop table #TempOptionTrade

		--create table #TempOptionTrade
		--(
		--	OptionTradeID int identity(1, 1) not null,
		--	ASXCode varchar(10) not null,
		--	Underlying varchar(10) not null,
		--	OptionSymbol varchar(100) not null,
		--	SaleTime datetime,
		--	Price decimal(20, 4),
		--	Size bigint,
		--	Exchange varchar(100),
		--	SpecialConditions varchar(200)
		--)

		--insert into #TempOptionTrade
		--(
		--   [ASXCode]
		--  ,[Underlying]
		--  ,[OptionSymbol]
		--  ,[SaleTime]
		--  ,[Price]
		--  ,[Size]
		--  ,[Exchange]
		--  ,[SpecialConditions]
		--)
		--select
		--   @pvchUnderlying + '.US' as [ASXCode]
		--  ,@pvchUnderlying as [Underlying]
		--  ,@pvchOptionSymbol as [OptionSymbol]
		--  ,@pdtSaleTime as [SaleTime]
		--  ,@pdecPrice as [Price]
		--  ,@pintSize as [Size]
		--  ,@pvchExchange as [Exchange]
		--  ,@pvchSpecialConditions as [SpecialConditions]

		declare @dtObservationDateLocal as date 
		select @dtObservationDateLocal = min(ObservationDateLocal)
		from #TempOptionTrade

		update a
		set OptionSymbol = replace(OptionSymbol, ' ', '')
		from #TempOptionTrade as a

		insert into StockData.OptionTrade
		(
		   [ASXCode]
		  ,[Underlying]
		  ,[OptionSymbol]
		  ,[SaleTime]
		  ,[Price]
		  ,[Size]
		  ,[Exchange]
		  ,[SpecialConditions]
		  ,[CreateDateTime]
		  ,[UpdateDateTime]
		  ,ObservationDateLocal
		  ,Strike
		  ,PorC
		  ,ExpiryDate
		  ,Expiry
		)
		select
		   [ASXCode]
		  ,[Underlying]
		  ,replace([OptionSymbol],  ' ', '')
		  ,[SaleTime]
		  ,[Price]
		  ,[Size]
		  ,[Exchange]
		  ,[SpecialConditions]
		  ,getdate() as [CreateDateTime]
		  ,getdate() as [UpdateDateTime]
		  ,ObservationDateLocal
		  ,Strike
		  ,PorC
		  ,ExpiryDate
		  ,Expiry
		from #TempOptionTrade as a
		where not exists
		(
			select 1
			from StockData.OptionTrade
			where ObservationDateLocal >= @dtObservationDateLocal
			and OptionSymbol = a.OptionSymbol
			and SaleTime = a.SaleTime
			and isnull(Price, -1) = isnull(a.Price, -1)
			and isnull(Size, -1) = isnull(a.Size, -1)
			and isnull(Exchange, '') = isnull(a.Exchange, '')
			and isnull(SpecialConditions, '') = isnull(a.SpecialConditions, '')
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
