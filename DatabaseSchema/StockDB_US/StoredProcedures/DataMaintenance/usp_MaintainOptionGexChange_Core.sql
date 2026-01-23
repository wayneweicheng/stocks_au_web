-- Stored procedure: [DataMaintenance].[usp_MaintainOptionGexChange_Core]





CREATE PROCEDURE [DataMaintenance].[usp_MaintainOptionGexChange_Core]
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
		--declare @pintPrevNumDay as int = 365*3
		declare @dtObservationDate as date = Common.DateAddBusinessDay(-1*@pintPrevNumDay, getdate()) 
		declare @dtObservationDateMinusN as date = Common.DateAddBusinessDay(-1*2, @dtObservationDate) 

		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuote_V2') is not null
			drop table #TempOptionDelayedQuote_V2

		select *
		into #TempOptionDelayedQuote_V2
		from [StockData].[v_OptionDelayedQuote_V2_Include_Archive]
		where ObservationDate >= @dtObservationDateMinusN
		and ASXCode in ('SPXW.US', 'SPX.US', 'QQQ.US', 'SPY.US', 'UVXX.US', 'VXX.US', 'IBIT.US', 'GDX.US', 'SLV.US', 'IWM.US', 'DIA.US', 'TLT.US', 'LABU.US', 'KWEB.US', 'CCJ.US', 'UEC.US', 'ALB.US', 'MP.US', 'CEG.US', 'RXRX.US')

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

		--create index idx_transformoptiondelayquoteallv2_asxcodeobdate on Transform.v_OptionDelayedQuote_All_V2(ASXCode, ObservationDate)		

		if object_id(N'Tempdb.dbo.#TempOptionGEXChange') is not null
			drop table #TempOptionGEXChange
			
		select y.*, x.[Close], x.VWAP
		into #TempOptionGEXChange
		from StockData.v_PriceHistory as x
		right join
		(
			select 
				ObservationDate, 
				ASXCode, 
				count(*) as NoOfOption,
				sum(case when PorC = 'C' then 1 else -1 end*Gamma*100*OpenInterest*1.0) as GEX,
				cast(sum(case when PorC = 'C' then 1 else -1 end*Gamma*100*(OpenInterest - Prev1OpenInterest)) as int) as GEXDeltaAdjusted,
				sum(case when PorC = 'C' then 1 else -1 end*Gamma*100*OpenInterest*1.0) - sum(case when PorC = 'C' then 1 else -1 end*Prev1Gamma*100*Prev1OpenInterest*1.0) as GEXDelta
			from #TempOptionDelayedQuote_All_V2
			where 1 = 1 
			--and ASXCode = 'ARKK.US'
			and ExpiryDate < dateadd(day, 30, ObservationDate)
			--and ObservationDate = '2023-09-12'
			group by ObservationDate, ASXCode
		) as y
		on x.ASXCode = y.ASXCode
		and x.ObservationDate = y.ObservationDate	

		delete a
		from Transform.OptionGEXChange as a
		inner join 
		(
			select distinct ObservationDate, ASXCode
			from #TempOptionGEXChange
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode
		and a.GEX is null

		insert into Transform.OptionGEXChange
		(
		   [ObservationDate]
		  ,[ASXCode]
		  ,[GEXDelta]
		  ,GEXDeltaAdjusted
		  ,[Close]
		  ,[VWAP]
		  ,[NoOfOption]
		  ,[GEX]
		)
		select 
		   [ObservationDate]
		  ,[ASXCode]
		  ,[GEXDelta]
		  ,GEXDeltaAdjusted
		  ,[Close]
		  ,[VWAP]
		  ,[NoOfOption]
		  ,[GEX]
		from #TempOptionGEXChange as a
		where not exists
		(
			select 1
			from Transform.OptionGEXChange
			where ObservationDate = a.ObservationDate
			and ASXCode = a.ASXCode
		)



		
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
