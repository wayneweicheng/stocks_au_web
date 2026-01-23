-- Stored procedure: [DataMaintenance].[usp_MaintainOptionGexChangeCapitalType]






CREATE PROCEDURE [DataMaintenance].[usp_MaintainOptionGexChangeCapitalType]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintPrevNumDay as int = 2
AS
/******************************************************************************
File: usp_MaintainStockData.sql
Stored Procedure Name: usp_MaintainStockData
Overview
-----------------
usp_MaintainStockData

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
Date:		2017-02-07
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_MaintainStockData'
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
		--declare @pintPrevNumDay as int = 168
		declare @dtObservationDate as date = Common.DateAddBusinessDay(-1*@pintPrevNumDay, getdate()) 
		declare @dtObservationDateMinusN as date = Common.DateAddBusinessDay(-1*2, @dtObservationDate) 
		select @dtObservationDateMinusN

		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuote_V2') is not null
			drop table #TempOptionDelayedQuote_V2

		select *
		into #TempOptionDelayedQuote_V2
		from [StockData].[v_OptionDelayedQuote_V2]
		where ObservationDate >= @dtObservationDateMinusN
		--and ASXCode = 'SPXW.US'

		--declare @dtObservationDate as date = '2023-09-18'
		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuote_All_V2') is not null
			drop table #TempOptionDelayedQuote_All_V2

		select * 
		into #TempOptionDelayedQuote_All_V2
		from (
			select
				*,
				lead(OpenInterest) over (partition by OptionSymbol order by ObservationDate desc) as Prev1OpenInterest,
				lead(Delta) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Delta,
				lead(Gamma) over (partition by OptionSymbol order by ObservationDate desc) as Prev1Gamma
			from #TempOptionDelayedQuote_V2
		) as x
		where ObservationDate >= @dtObservationDate

		update a
		set a.OpenInterest = a.Prev1OpenInterest + case when a.OpenInterest > a.Prev1OpenInterest then 1 else -1 end*Volume
		--set a.OpenInterest = a.Prev1OpenInterest
		from #TempOptionDelayedQuote_All_V2 as a
		where Volume < abs(OpenInterest - Prev1OpenInterest)
		and Volume > 0
		--and ObservationDate = '2023-11-30'
		
		update a
		set Gamma = null
		from #TempOptionDelayedQuote_All_V2 as a

		update a
		set a.Gamma = b.Gamma
		from #TempOptionDelayedQuote_All_V2 as a
		inner join [StockData].[v_OptionDelayedQuote] as b
		on a.ASXCode = b.ASXCode
		and a.OptionSymbol = b.OptionSymbol
		and a.ObservationDate = b.ObservationDate

		delete a
		from #TempOptionDelayedQuote_All_V2 as a
		where Gamma is null

		--select abs(OpenInterest - Prev1OpenInterest), a.Prev1OpenInterest + case when a.OpenInterest > a.Prev1OpenInterest then 1 else -1 end*Volume, *
		--from #TempOptionDelayedQuote_All_V2 as a
		--where Volume < abs(OpenInterest - Prev1OpenInterest)
		--and ObservationDate = '2023-11-30'
		--and abs(OpenInterest - Prev1OpenInterest) > 0

		--create index idx_transformoptiondelayquoteallv2_asxcodeobdate on Transform.v_OptionDelayedQuote_All_V2(ASXCode, ObservationDate)		

		if object_id(N'Tempdb.dbo.#TempOptionGEXChange') is not null
			drop table #TempOptionGEXChange
			
		select y.*, x.[Close], x.VWAP
		into #TempOptionGEXChange
		from StockData.v_PriceHistory as x
		right join
		(
			select 
				ObservationDate, ASXCode, 
				case when PorC = 'P' and OpenInterest - Prev1OpenInterest > 0 then 'BP' 
					 when PorC = 'P' and OpenInterest - Prev1OpenInterest < 0 then 'SP' 
					 when PorC = 'C' and OpenInterest - Prev1OpenInterest > 0 then 'BC' 
				     when PorC = 'C' and OpenInterest - Prev1OpenInterest < 0 then 'SC' 
				end as CapitalType, 
				count(*) as NoOfOption,
				sum(case when PorC = 'C' then 1 else -1 end*Gamma*100*OpenInterest*1.0) as GEX,
				cast(sum(case when PorC = 'C' then 1 else -1 end*Gamma*100*(OpenInterest - Prev1OpenInterest)) as int) as GEXDelta 
			from #TempOptionDelayedQuote_All_V2
			where 1 = 1 
			--and ASXCode = 'SPXW.US'
			and ExpiryDate < dateadd(day, 120, ObservationDate)
			--and ObservationDate = '2023-09-12'
			group by 
				ObservationDate, 
				ASXCode, 
				case when PorC = 'P' and OpenInterest - Prev1OpenInterest > 0 then 'BP' 
					 when PorC = 'P' and OpenInterest - Prev1OpenInterest < 0 then 'SP' 
					 when PorC = 'C' and OpenInterest - Prev1OpenInterest > 0 then 'BC' 
				     when PorC = 'C' and OpenInterest - Prev1OpenInterest < 0 then 'SC' 
				end
			--order by 
			--	ObservationDate, 
			--	ASXCode, 
			--	case when PorC = 'P' and OpenInterest - Prev1OpenInterest > 0 then 'BP' 
			--		 when PorC = 'P' and OpenInterest - Prev1OpenInterest < 0 then 'SP' 
			--		 when PorC = 'C' and OpenInterest - Prev1OpenInterest > 0 then 'BC' 
			--	     when PorC = 'C' and OpenInterest - Prev1OpenInterest < 0 then 'SC' 
			--	end
		) as y
		on x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate	
		
		delete a
		from Transform.OptionGEXChangeCapitalType as a
		inner join 
		(
			select distinct ObservationDate, ASXCode
			from #TempOptionGEXChange
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode

		insert into Transform.OptionGEXChangeCapitalType
		(
			[ObservationDate],
			[ASXCode],
			NoOfOption,
			GEX,
			[GEXDelta],
			[CapitalType],
			[Close],
			[VWAP]
		)
		select 
			[ObservationDate],
			[ASXCode],
			NoOfOption,
			GEX,
			[GEXDelta],
			[CapitalType],
			[Close],
			[VWAP]		
		from #TempOptionGEXChange
		
		if object_id(N'Tempdb.dbo.#TempPC') is not null
			drop table #TempPC
		
		select *
		into #TempPC
		from (
			select 
				ASXCode, 
				ObservationDate,
				PorC,
				case when PorC = 'C' then 1 else -1 end*cast(sum(a.Gamma*a.OpenInterest*100) as bigint) as Delta
			from [StockData].[v_OptionDelayedQuote_V2] as a
			where 1 = 1
			group by 
				ASXCode, 
				ObservationDate,
				PorC
		) as x
		where 1 = 1 
		and ObservationDate > dateadd(day, -10, getdate())
		--and ASXCode = 'SPXW.US'
		order by ObservationDate desc

		delete a
		from Transform.OptionGEXByPutCall as a
		inner join #TempPC as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate

		insert into Transform.OptionGEXByPutCall
		select * from #TempPC

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()

		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_MaintainStockData failed'
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
