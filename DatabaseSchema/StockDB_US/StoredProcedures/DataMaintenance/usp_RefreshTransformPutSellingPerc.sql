-- Stored procedure: [DataMaintenance].[usp_RefreshTransformPutSellingPerc]





CREATE PROCEDURE [DataMaintenance].[usp_RefreshTransformPutSellingPerc]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshTransformPutSellingPerc.sql
Stored Procedure Name: usp_RefreshTransformPutSellingPerc
Overview
-----------------
usp_RefreshTransformPutSellingPerc

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
Date:		2021-09-22
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformPutSellingPerc'
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
		--declare @pintNumPrevDay as int = 0
		--declare @intNumLookBackNoDays as int = 10
		if object_id(N'Tempdb.dbo.#TempGEX') is not null
			drop table #TempGEX

		select 
			a.ObservationDate,
			a.ASXCode,
			case when (b.PorC = 'P' and c.[Close] <= b.Strike) or (b.PorC = 'C' and c.[Close] >= b.Strike) then 'ITM'
					when (b.PorC = 'P' and c.[Close] > b.Strike) or (b.PorC = 'C' and c.[Close] < b.Strike) then 'OTM'
					else 'Unknown'
			end as IOrO,
			a.LongShortIndicator,
			sum(a.Size*100*d.Gamma) as GEX
		into #TempGEX
		from [StockData].[v_OptionTrade] as a with(nolock)
		inner join StockData.OptionContract as b with(nolock)
		on a.OptionSymbol = b.OptionSymbol
		inner join [StockData].[v_OptionDelayedQuote] as d with(nolock)
		on a.OptionSymbol = d.OptionSymbol
		left join StockData.v_PriceHistory as c
		on c.ASXCode = a.ASXCode
		and a.ObservationDate = c.ObservationDate
		where 1 = 1
		and a.ASXCode = 'SPY.US'
		and a.ObservationDate > dateadd(day, -5, getdate())
		group by 
			a.ObservationDate,
			a.ASXCode,
			case when (b.PorC = 'P' and c.[Close] <= b.Strike) or (b.PorC = 'C' and c.[Close] >= b.Strike) then 'ITM'
					when (b.PorC = 'P' and c.[Close] > b.Strike) or (b.PorC = 'C' and c.[Close] < b.Strike) then 'OTM'
					else 'Unknown'
			end,
			a.LongShortIndicator

		select a.ASXCode, a.ObservationDate, LongGex*100.0/TotalGex as PutSellPerc
		into #TempPutSellPerc
		from
		(
			select ASXCode, ObservationDate, sum(GEX) as LongGex
			from #TempGEX as a
			where IOrO= 'OTM'
			and LongShortIndicator = 'Long'
			group by ASXCode, ObservationDate
		) as a
		inner join
		(
			select ASXCode, ObservationDate, sum(GEX) as TotalGex
			from #TempGEX as a
			where IOrO= 'OTM'
			and LongShortIndicator in ('Long', 'Short')
			group by ASXCode, ObservationDate
		) as b
		on a.ASXCode = b.ASXCode
		and a.ObservationDate = b.ObservationDate
		order by ObservationDate desc;
		
		delete a
		from Transform.PutSellingPerc as a
		inner join #TempPutSellPerc as b
		on a.ObservationDate = b.ObservationDate
		and a.ASXCode = b.ASXCode

		insert into Transform.PutSellingPerc
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[PutSellPerc]
		  ,[CreateDate]
		)
		select
		   [ASXCode]
		  ,[ObservationDate]
		  ,[PutSellPerc]
		  ,getdate() as [CreateDate]
		from #TempPutSellPerc as a

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
		
		declare @vchEmailRecipient as varchar(100) = 'wayneweicheng@gmail.com'
		declare @vchEmailSubject as varchar(200) = 'DataMaintenance.usp_RefreshTransformBrokerReportList failed'
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