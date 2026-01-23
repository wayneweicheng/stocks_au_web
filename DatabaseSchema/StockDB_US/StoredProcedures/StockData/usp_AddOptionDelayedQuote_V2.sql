-- Stored procedure: [StockData].[usp_AddOptionDelayedQuote_V2]



CREATE PROCEDURE [StockData].[usp_AddOptionDelayedQuote_V2]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchResponse as varchar(max),
@bitFixYesterday as bit = 0
AS
/******************************************************************************
File: usp_AddOptionDelayedQuote.sql
Stored Procedure Name: usp_AddOptionDelayedQuote
Overview
-----------------
usp_AddOptionDelayedQuote

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
Date:		2017-02-06
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = object_name(@@PROCID)
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = schema_name()
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations
		--declare @bitFixYesterday as bit = 1
		declare @dtObservationDate as date
		if datepart(hour, getdate()) < 10
		begin
			select @bitFixYesterday = 1
		end
		if @bitFixYesterday = 0
		begin
			select @dtObservationDate = Common.DateAddBusinessDay(-1, cast(getdate() as date))
		end
		else
		begin
			select @dtObservationDate = Common.DateAddBusinessDay(-2, cast(getdate() as date))
		end

		--Code goes here 
		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuote') is not null
			drop table #TempOptionDelayedQuote

		select
			@pvchASXCode as ASXCode,
			@pvchResponse as Quote
		into #TempOptionDelayedQuote
		--into MAWork.dbo.TempOptionDelayedQuote

		if object_id(N'Tempdb.dbo.#TempParsedOptionDelayedQuote') is not null
			drop table #TempParsedOptionDelayedQuote
		
		select 
			a.ASXCode,
			@dtObservationDate as ObservationDate,
			cast(json_value(c.value, '$.option') as varchar(200)) as OptionSymbol,
			cast(json_value(c.value, '$.bid') as decimal(20, 4)) as Bid,
			cast(json_value(c.value, '$.bid_size') as decimal(20, 4)) as BidSize,
			cast(json_value(c.value, '$.ask') as decimal(20, 4)) as Ask,
			cast(json_value(c.value, '$.ask_size') as decimal(20, 4)) as AskSize,
			cast(json_value(c.value, '$.iv') as decimal(20, 4)) as IV,
			cast(json_value(c.value, '$."open_interest"') as decimal(20, 4)) as OpenInterest,
			cast(json_value(c.value, '$.volume') as decimal(20, 4)) as Volume,
			cast(json_value(c.value, '$.delta') as decimal(20, 4)) as Delta,
			cast(json_value(c.value, '$.gamma') as decimal(20, 4)) as Gamma,
			cast(json_value(c.value, '$.theta') as decimal(20, 4)) as Theta,
			cast(json_value(c.value, '$.rho') as decimal(20, 4)) as RHO,
			cast(json_value(c.value, '$.vega') as decimal(20, 4)) as Vega,
			cast(json_value(c.value, '$.theo') as decimal(20, 4)) as Theo,
			cast(json_value(c.value, '$.change') as decimal(20, 4)) as Change,
			cast(json_value(c.value, '$.open') as decimal(20, 4)) as [Open],
			cast(json_value(c.value, '$.high') as decimal(20, 4)) as [High],
			cast(json_value(c.value, '$.low') as decimal(20, 4)) as [Low],
			cast(json_value(c.value, '$.tick') as varchar(100)) as [Tick],
			cast(json_value(c.value, '$.last_trade_price') as decimal(20, 4)) as [LastTradePrice],
			cast(json_value(c.value, '$.last_trade_time') as varchar(100)) as [LastTradeTime],
			cast(json_value(c.value, '$.prev_day_close') as varchar(100)) as [PrevDayClose],
			cast(null as decimal(20, 4)) as Strike,
			cast(null as char(1)) as PorC,
			cast(null as date) as ExpiryDate,
			cast(null as varchar(8)) as Expiry
		into #TempParsedOptionDelayedQuote
		--into MAWork.dbo.ParsedOptionDelayedQuote
		from #TempOptionDelayedQuote as a
		cross apply openjson(Quote) as b
		cross apply openjson(b.value) as c
		where b.[key] = 'options'

		update a
		set LastTradeTime = cast(LastTradeTime as datetime)
		from #TempParsedOptionDelayedQuote as a

		update a
		set 
			a.ASXCode = 
			   case when [ASXCode] = '_SPX.US' and OptionSymbol like 'SPXW%' then 'SPXW.US' 
					when [ASXCode] = '_SPX.US' and OptionSymbol not like 'SPXW%' then 'SPX.US' 
					else [ASXCode]
			   end
		from #TempParsedOptionDelayedQuote as a
		where [ASXCode] = '_SPX.US'

		update a
		set 
			Strike = cast(reverse(substring(reverse(OptionSymbol), 1, 8)) as decimal(20, 4))/1000.0,
			PorC = reverse(substring(reverse(OptionSymbol), 9, 1)),
			ExpiryDate = '20' + left(reverse(substring(reverse(OptionSymbol), 10, 6)), 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 3, 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 5, 2)	
		from #TempParsedOptionDelayedQuote as a

		update a
		set ExpiryDate = dateadd(day, -1, ExpiryDate)
		from #TempParsedOptionDelayedQuote as a
		where ASXCode = 'SPX.US'

		update a
		set Expiry = convert(varchar(8), ExpiryDate, 112)
		from #TempParsedOptionDelayedQuote as a

		if object_id(N'Tempdb.dbo.#TempToDelete') is not null
			drop table #TempToDelete

		select *
		into #TempToDelete
		from
		(
			select a.*
			from StockData.OptionDelayedQuote_V2 as a
			where ObservationDate = @dtObservationDate 
			and exists
			(
				select 1
				from #TempParsedOptionDelayedQuote as b
				where a.ASXCode = b.ASXCode
				and a.OptionSymbol = b.OptionSymbol
				and a.ObservationDate = b.ObservationDate
			)
			and '20' + left(reverse(substring(reverse(OptionSymbol), 10, 6)), 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 3, 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 5, 2) > ObservationDate
			union all
			select a.*
			from StockData.OptionDelayedQuote_V2 as a
			where ObservationDate = @dtObservationDate 
			and exists
			(
				select 1
				from #TempParsedOptionDelayedQuote as b
				where a.ASXCode = b.ASXCode
				and a.OptionSymbol = b.OptionSymbol
				and a.ObservationDate = b.ObservationDate
				and b.Gamma > 0
			)
			and '20' + left(reverse(substring(reverse(OptionSymbol), 10, 6)), 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 3, 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 5, 2) = ObservationDate
		) as x

		delete a
		from #TempParsedOptionDelayedQuote as a
		where '20' + left(reverse(substring(reverse(OptionSymbol), 10, 6)), 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 3, 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 5, 2) = ObservationDate
		and Gamma = 0

		delete a
		from #TempParsedOptionDelayedQuote as a
		where ObservationDate = ExpiryDate

		insert into [StockData].[OptionDelayedQuoteHistory_V2]
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[OptionSymbol]
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[IV]
		  ,[OpenInterest]
		  ,[Volume]
		  ,[Delta]
		  ,[Gamma]
		  ,[Theta]
		  ,[RHO]
		  ,[Vega]
		  ,[Theo]
		  ,[Change]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Tick]
		  ,[LastTradePrice]
		  ,[LastTradeTime]
		  ,[PrevDayClose]
		  ,[CreateDate]
		  ,Strike
		  ,PorC
		  ,ExpiryDate
		  ,Expiry
		)
		select
		   [ASXCode]
		  ,[ObservationDate]
		  ,[OptionSymbol]
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[IV]
		  ,[OpenInterest]
		  ,[Volume]
		  ,[Delta]
		  ,[Gamma]
		  ,[Theta]
		  ,[RHO]
		  ,[Vega]
		  ,[Theo]
		  ,[Change]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Tick]
		  ,[LastTradePrice]
		  ,[LastTradeTime]
		  ,[PrevDayClose]
		  ,[CreateDate]
		  ,Strike
		  ,PorC
		  ,ExpiryDate
		  ,Expiry
		from #TempToDelete

		delete a
		from StockData.OptionDelayedQuote_V2 as a
		inner join #TempToDelete as b
		on a.ASXCode = b.ASXCode
		and a.OptionSymbol = b.OptionSymbol
		and a.CreateDate = b.CreateDate

		insert into StockData.OptionDelayedQuote_V2
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[OptionSymbol]
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[IV]
		  ,[OpenInterest]
		  ,[Volume]
		  ,[Delta]
		  ,[Gamma]
		  ,[Theta]
		  ,[RHO]
		  ,[Vega]
		  ,[Theo]
		  ,[Change]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Tick]
		  ,[LastTradePrice]
		  ,[LastTradeTime]
		  ,[PrevDayClose]
		  ,[CreateDate]
		  ,Strike
		  ,PorC
		  ,ExpiryDate
		  ,Expiry
		)
		select
	       [ASXCode]
		  ,[ObservationDate]
		  ,replace([OptionSymbol], ' ', '')
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[IV]
		  ,[OpenInterest]
		  ,[Volume]
		  ,[Delta]
		  ,[Gamma]
		  ,[Theta]
		  ,[RHO]
		  ,[Vega]
		  ,[Theo]
		  ,[Change]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Tick]
		  ,[LastTradePrice]
		  ,[LastTradeTime]
		  ,[PrevDayClose]
		  ,getdate() as [CreateDate]
		  ,Strike
		  ,PorC
		  ,ExpiryDate
		  ,Expiry
		from #TempParsedOptionDelayedQuote

		delete a
		from StockData.OptionDelayedQuote_V2 as a
		where ASXCode = @pvchASXCode
		and '20' + left(reverse(substring(reverse(OptionSymbol), 10, 6)), 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 3, 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 5, 2) < ObservationDate

		insert into StockData.OptionDelayedQuote_V2
		(
			 [ASXCode]
			,[ObservationDate]
			,[OptionSymbol]
			,[Bid]
			,[BidSize]
			,[Ask]
			,[AskSize]
			,[IV]
			,[OpenInterest]
			,[Volume]
			,[Delta]
			,[Gamma]
			,[Theta]
			,[RHO]
			,[Vega]
			,[Theo]
			,[Change]
			,[Open]
			,[High]
			,[Low]
			,[Tick]
			,[LastTradePrice]
			,[LastTradeTime]
			,[PrevDayClose]
			,[CreateDate]	
			,Strike
			,PorC
			,ExpiryDate
			,Expiry
		)
		select 
			 [ASXCode]
			,[ObservationDate]
			,[OptionSymbol]
			,[Bid]
			,[BidSize]
			,[Ask]
			,[AskSize]
			,[IV]
			,[OpenInterest]
			,[Volume]
			,[Delta]
			,[Gamma]
			,[Theta]
			,[RHO]
			,[Vega]
			,[Theo]
			,[Change]
			,[Open]
			,[High]
			,[Low]
			,[Tick]
			,[LastTradePrice]
			,[LastTradeTime]
			,[PrevDayClose]
			,[CreateDate]
			,Strike
			,PorC
			,ExpiryDate
			,Expiry
		from
		(
			select
				 [ASXCode]
				,[ObservationDate]
				,[OptionSymbol]
				,[Bid]
				,[BidSize]
				,[Ask]
				,[AskSize]
				,[IV]
				,[OpenInterest]
				,[Volume]
				,[Delta]
				,[Gamma]
				,[Theta]
				,[RHO]
				,[Vega]
				,[Theo]
				,[Change]
				,[Open]
				,[High]
				,[Low]
				,[Tick]
				,[LastTradePrice]
				,[LastTradeTime]
				,[PrevDayClose]
				,[CreateDate]
				,Strike
				,PorC
				,ExpiryDate
				,Expiry
				,row_number() over (partition by ASXCode, OptionSymbol, ObservationDate order by CreateDate desc) as RowNumber
			from StockData.OptionDelayedQuoteHistory as a
			where '20' + left(reverse(substring(reverse(OptionSymbol), 10, 6)), 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 3, 2) + '-' + substring(reverse(substring(reverse(OptionSymbol), 10, 6)), 5, 2) = a.ObservationDate
			and Gamma > 0
			and ASXCode = @pvchASXCode
		) as x
		where 1= 1 
		and x.ASXCode = @pvchASXCode
		and x.ObservationDate = @dtObservationDate
		and x.RowNumber = 1
		and not exists
		(
			select 1
			from StockData.OptionDelayedQuote_V2
			where OptionSymbol = x.OptionSymbol
			and ObservationDate = x.ObservationDate
			and ASXCode = @pvchASXCode
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
			
		EXECUTE DA_Utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
